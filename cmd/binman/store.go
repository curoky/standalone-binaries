package main

import (
	"archive/tar"
	"bytes"
	"compress/gzip"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"os"
	"path"
	"path/filepath"
	"strings"

	"golang.org/x/sys/unix"
)

type metadata struct {
	Digest string   `json:"digest"`
	LinkTo []string `json:"linkTo,omitempty"`
}

func internalPath(prefix string) string {
	return filepath.Join(prefix, ".binman")
}

func storePath(prefix, packageName string) string {
	return filepath.Join(internalPath(prefix), "store", packageName)
}

func metaPath(prefix, packageName string) string {
	return filepath.Join(storePath(prefix, packageName), metaFile)
}

func readMetadata(prefix, packageName string) (metadata, bool, error) {
	var value metadata
	info, err := os.Lstat(storePath(prefix, packageName))
	if os.IsNotExist(err) {
		return value, false, nil
	}
	if err != nil {
		return value, false, err
	}
	if !info.IsDir() || info.Mode()&os.ModeSymlink != 0 {
		return value, false, fmt.Errorf("%s: package store is not a directory", packageName)
	}
	data, err := os.ReadFile(metaPath(prefix, packageName))
	if err != nil {
		return value, false, fmt.Errorf("%s: read metadata: %w", packageName, err)
	}
	decoder := json.NewDecoder(bytes.NewReader(data))
	decoder.DisallowUnknownFields()
	if err := decoder.Decode(&value); err != nil {
		return value, false, fmt.Errorf("%s: read metadata: %w", packageName, err)
	}
	var extra any
	if err := decoder.Decode(&extra); err != io.EOF {
		return value, false, fmt.Errorf("%s: metadata has trailing content", packageName)
	}
	if value.Digest == "" {
		return value, false, fmt.Errorf("%s: metadata has no digest", packageName)
	}
	for _, root := range value.LinkTo {
		clean, err := cleanLinkTo(root)
		if err != nil || clean == "" || clean != root {
			return value, false, fmt.Errorf("%s: metadata has invalid link target %q", packageName, root)
		}
	}
	return value, true, nil
}

func writeMetadata(store string, value metadata) error {
	data, err := json.Marshal(value)
	if err != nil {
		return err
	}
	return writeAtomic(filepath.Join(store, metaFile), 0o644, bytes.NewReader(data))
}

func writeAtomic(filename string, mode os.FileMode, reader io.Reader) error {
	if err := os.MkdirAll(filepath.Dir(filename), 0o755); err != nil {
		return err
	}
	file, err := os.CreateTemp(filepath.Dir(filename), "."+filepath.Base(filename)+".tmp-")
	if err != nil {
		return err
	}
	temporary := file.Name()
	defer os.Remove(temporary)
	if err := file.Chmod(mode); err != nil {
		_ = file.Close()
		return err
	}
	if _, err := io.Copy(file, reader); err != nil {
		_ = file.Close()
		return err
	}
	if err := file.Close(); err != nil {
		return err
	}
	return os.Rename(temporary, filename)
}

func extractTarGz(filename, destination, packageName string) error {
	file, err := os.Open(filename)
	if err != nil {
		return err
	}
	defer file.Close()
	gzipReader, err := gzip.NewReader(file)
	if err != nil {
		return err
	}
	defer gzipReader.Close()

	tarReader := tar.NewReader(gzipReader)
	buffer := make([]byte, 32*1024)
	for {
		header, err := tarReader.Next()
		if err == io.EOF {
			return nil
		}
		if err != nil {
			return err
		}
		relative, err := archiveRelativePath(header.Name, packageName)
		if err != nil {
			return err
		}
		if relative == "" {
			continue
		}
		if relative == metaFile {
			return fmt.Errorf("archive contains reserved path %s", header.Name)
		}
		target, err := safeArchivePath(destination, relative)
		if err != nil {
			return fmt.Errorf("unsafe archive path %s: %w", header.Name, err)
		}
		if err := rejectSymlinkParents(destination, target); err != nil {
			return fmt.Errorf("unsafe archive path %s: %w", header.Name, err)
		}

		switch header.Typeflag {
		case tar.TypeDir:
			err = os.MkdirAll(target, 0o755)
		case tar.TypeReg, tar.TypeRegA:
			if info, statErr := os.Lstat(target); statErr == nil && info.Mode()&os.ModeSymlink != 0 {
				return fmt.Errorf("archive file replaces symlink: %s", header.Name)
			} else if statErr != nil && !os.IsNotExist(statErr) {
				return statErr
			}
			err = writeFile(target, tarReader, os.FileMode(header.Mode)&0o777, buffer)
		case tar.TypeSymlink:
			var linkTarget string
			linkTarget, err = safeSymlinkTarget(destination, target, header.Linkname)
			if err == nil {
				err = os.MkdirAll(filepath.Dir(target), 0o755)
			}
			if err == nil {
				if removeErr := os.Remove(target); removeErr != nil && !os.IsNotExist(removeErr) {
					return removeErr
				}
				var relativeTarget string
				relativeTarget, err = filepath.Rel(filepath.Dir(target), linkTarget)
				if err == nil {
					err = os.Symlink(relativeTarget, target)
				}
			}
		case tar.TypeLink:
			var linkRelative string
			linkRelative, err = archiveRelativePath(header.Linkname, packageName)
			if err == nil && linkRelative == "" {
				err = fmt.Errorf("hardlink points to archive root")
			}
			var linkTarget string
			if err == nil {
				linkTarget, err = safeArchivePath(destination, linkRelative)
			}
			if err == nil {
				err = rejectSymlinkParents(destination, linkTarget)
			}
			if err == nil {
				err = os.MkdirAll(filepath.Dir(target), 0o755)
			}
			if err == nil {
				err = os.Link(linkTarget, target)
			}
		default:
			return fmt.Errorf("unsupported tar entry type %d for %s", header.Typeflag, header.Name)
		}
		if err != nil {
			return fmt.Errorf("extract %s: %w", header.Name, err)
		}
	}
}

func archiveRelativePath(name, packageName string) (string, error) {
	for strings.HasPrefix(name, "./") {
		name = strings.TrimPrefix(name, "./")
	}
	if name == "" || strings.HasPrefix(name, "/") {
		return "", fmt.Errorf("invalid archive path %q", name)
	}
	clean := path.Clean(name)
	if clean == packageName {
		return "", nil
	}
	root, relative, ok := strings.Cut(clean, "/")
	if !ok || root != packageName || relative == "" {
		return "", fmt.Errorf("archive path %q is not rooted at %s", name, packageName)
	}
	return filepath.FromSlash(relative), nil
}

func safeArchivePath(root, relative string) (string, error) {
	if filepath.IsAbs(relative) {
		return "", fmt.Errorf("absolute path")
	}
	target := filepath.Clean(filepath.Join(root, relative))
	if !withinRoot(root, target) {
		return "", fmt.Errorf("path escapes extraction root")
	}
	return target, nil
}

func safeSymlinkTarget(root, linkPath, linkName string) (string, error) {
	if filepath.IsAbs(linkName) {
		return "", fmt.Errorf("absolute target")
	}
	target := filepath.Clean(filepath.Join(filepath.Dir(linkPath), filepath.FromSlash(linkName)))
	if !withinRoot(root, target) {
		return "", fmt.Errorf("target escapes extraction root")
	}
	return target, nil
}

func withinRoot(root, target string) bool {
	root = filepath.Clean(root)
	return target != root && strings.HasPrefix(target, root+string(os.PathSeparator))
}

func rejectSymlinkParents(root, target string) error {
	relative, err := filepath.Rel(root, filepath.Dir(target))
	if err != nil {
		return err
	}
	current := filepath.Clean(root)
	if relative == "." {
		return nil
	}
	for _, part := range strings.Split(relative, string(os.PathSeparator)) {
		current = filepath.Join(current, part)
		info, err := os.Lstat(current)
		switch {
		case os.IsNotExist(err):
			return nil
		case err != nil:
			return err
		case info.Mode()&os.ModeSymlink != 0:
			return fmt.Errorf("parent %s is a symlink", current)
		case !info.IsDir():
			return fmt.Errorf("parent %s is not a directory", current)
		}
	}
	return nil
}

func writeFile(filename string, reader io.Reader, mode os.FileMode, buffer []byte) error {
	if err := os.MkdirAll(filepath.Dir(filename), 0o755); err != nil {
		return err
	}
	file, err := os.OpenFile(filename, os.O_CREATE|os.O_TRUNC|os.O_WRONLY, mode)
	if err != nil {
		return err
	}
	_, copyErr := io.CopyBuffer(struct{ io.Writer }{file}, reader, buffer)
	closeErr := file.Close()
	if copyErr != nil {
		return copyErr
	}
	return closeErr
}

type packageFile struct {
	Absolute string
	Relative string
}

func collectPackageFiles(store string) ([]packageFile, error) {
	resolvedStore, err := filepath.EvalSymlinks(store)
	if err != nil {
		return nil, err
	}
	var files []packageFile
	active := make(map[string]bool)
	var walk func(string, string, string) error
	walk = func(current, relative, resolved string) error {
		if resolved != resolvedStore && !withinRoot(resolvedStore, resolved) {
			return fmt.Errorf("directory link %s escapes package store", current)
		}
		if active[resolved] {
			return fmt.Errorf("directory link cycle at %s", current)
		}
		active[resolved] = true
		defer delete(active, resolved)

		entries, err := os.ReadDir(current)
		if err != nil {
			return err
		}
		for _, entry := range entries {
			childAbsolute := filepath.Join(current, entry.Name())
			childRelative := filepath.Join(relative, entry.Name())
			if childRelative == metaFile {
				continue
			}
			if childRelative == ".binman" || strings.HasPrefix(childRelative, ".binman"+string(os.PathSeparator)) {
				return fmt.Errorf("package contains reserved path %s", childRelative)
			}
			if entry.Type()&os.ModeSymlink != 0 {
				targetInfo, statErr := os.Stat(childAbsolute)
				if statErr == nil && targetInfo.IsDir() {
					target, err := filepath.EvalSymlinks(childAbsolute)
					if err != nil {
						return err
					}
					if err := walk(childAbsolute, childRelative, target); err != nil {
						return err
					}
					continue
				}
				if statErr != nil && !os.IsNotExist(statErr) {
					return statErr
				}
			} else if entry.IsDir() {
				if err := walk(childAbsolute, childRelative, filepath.Join(resolved, entry.Name())); err != nil {
					return err
				}
				continue
			}
			files = append(files, packageFile{Absolute: childAbsolute, Relative: childRelative})
		}
		return nil
	}
	if err := walk(store, "", resolvedStore); err != nil {
		return nil, err
	}
	return files, nil
}

func linkPackage(prefix, packageName, linkTo string) error {
	files, err := collectPackageFiles(storePath(prefix, packageName))
	if err != nil {
		return err
	}
	root := filepath.Join(prefix, linkTo)
	if err := ensureDirectory(prefix, root); err != nil {
		return err
	}
	var previousDirectory string
	for _, file := range files {
		destination := filepath.Join(root, file.Relative)
		directory := filepath.Dir(destination)
		if directory != previousDirectory {
			if err := ensureDirectory(root, directory); err != nil {
				return err
			}
			previousDirectory = directory
		}
		relativeTarget, err := filepath.Rel(filepath.Dir(destination), file.Absolute)
		if err != nil {
			return err
		}
		info, err := os.Lstat(destination)
		if err == nil {
			if info.Mode()&os.ModeSymlink == 0 {
				return fmt.Errorf("refusing to replace non-symlink %s", destination)
			}
			current, err := os.Readlink(destination)
			if err != nil {
				return err
			}
			if current == relativeTarget {
				continue
			}
			if err := os.Remove(destination); err != nil {
				return err
			}
		} else if !os.IsNotExist(err) {
			return err
		}
		if err := os.Symlink(relativeTarget, destination); err != nil {
			return err
		}
	}
	return nil
}

func unlinkPackage(prefix, packageName string, roots []string) error {
	files, err := collectPackageFiles(storePath(prefix, packageName))
	if err != nil {
		return err
	}
	for _, linkTo := range roots {
		root := filepath.Join(prefix, linkTo)
		if err := rejectSymlinkParents(prefix, filepath.Join(root, ".link-root")); err != nil {
			return err
		}
		var previousDirectory string
		for _, file := range files {
			destination := filepath.Join(root, file.Relative)
			if directory := filepath.Dir(destination); directory != previousDirectory {
				if err := rejectSymlinkParents(root, destination); err != nil {
					return err
				}
				previousDirectory = directory
			}
			owned, err := symlinkPointsTo(destination, file.Absolute)
			if os.IsNotExist(err) {
				continue
			}
			if err != nil {
				return err
			}
			if owned {
				if err := os.Remove(destination); err != nil {
					return err
				}
			}
		}
	}
	return nil
}

func ensureDirectory(root, directory string) error {
	relative, err := filepath.Rel(root, directory)
	if err != nil {
		return err
	}
	if relative == ".." || strings.HasPrefix(relative, ".."+string(os.PathSeparator)) {
		return fmt.Errorf("directory %s escapes link root", directory)
	}
	if err := os.MkdirAll(root, 0o755); err != nil {
		return err
	}
	current := filepath.Clean(root)
	if relative == "." {
		return nil
	}
	for _, part := range strings.Split(relative, string(os.PathSeparator)) {
		current = filepath.Join(current, part)
		info, err := os.Lstat(current)
		if os.IsNotExist(err) {
			if err := os.Mkdir(current, 0o755); err != nil {
				return err
			}
			continue
		}
		if err != nil {
			return err
		}
		if !info.IsDir() || info.Mode()&os.ModeSymlink != 0 {
			return fmt.Errorf("link parent %s is not a real directory", current)
		}
	}
	return nil
}

func symlinkPointsTo(link, target string) (bool, error) {
	info, err := os.Lstat(link)
	if err != nil {
		return false, err
	}
	if info.Mode()&os.ModeSymlink == 0 {
		return false, nil
	}
	linkTarget, err := os.Readlink(link)
	if err != nil {
		return false, err
	}
	if !filepath.IsAbs(linkTarget) {
		linkTarget = filepath.Join(filepath.Dir(link), linkTarget)
	}
	return filepath.Clean(linkTarget) == filepath.Clean(target), nil
}

func replaceStore(prefix, packageName, staged string) error {
	store := storePath(prefix, packageName)
	if err := ensureDirectory(internalPath(prefix), filepath.Dir(store)); err != nil {
		return err
	}
	backup := staged + ".old"
	if _, err := os.Lstat(store); err == nil {
		if err := os.Rename(store, backup); err != nil {
			return err
		}
		if err := os.Rename(staged, store); err != nil {
			return errors.Join(err, os.Rename(backup, store))
		}
		return os.RemoveAll(backup)
	} else if !os.IsNotExist(err) {
		return err
	}
	return os.Rename(staged, store)
}

func withPrefixLock(prefix string, operation func() error) error {
	directory := internalPath(prefix)
	if err := ensureDirectory(prefix, directory); err != nil {
		return err
	}
	if err := ensureDirectory(directory, filepath.Join(directory, "store")); err != nil {
		return err
	}
	file, err := os.OpenFile(filepath.Join(directory, "lock"), os.O_CREATE|os.O_RDWR, 0o600)
	if err != nil {
		return err
	}
	if err := unix.Flock(int(file.Fd()), unix.LOCK_EX); err != nil {
		_ = file.Close()
		return err
	}
	operationErr := operation()
	unlockErr := unix.Flock(int(file.Fd()), unix.LOCK_UN)
	return errors.Join(operationErr, unlockErr, file.Close())
}
