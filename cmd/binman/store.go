package main

import (
	"archive/tar"
	"compress/gzip"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"io/fs"
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

func storeRoot(prefix string) string { return filepath.Join(prefix, "store") }

func storePath(prefix, packageName string) string {
	return filepath.Join(storeRoot(prefix), packageName)
}

func readMetadata(prefix, packageName string) (metadata, bool, error) {
	var value metadata
	store := storePath(prefix, packageName)
	info, err := os.Lstat(store)
	if os.IsNotExist(err) {
		return value, false, nil
	}
	if err != nil {
		return value, false, err
	}
	if !info.IsDir() || info.Mode()&os.ModeSymlink != 0 {
		return value, false, fmt.Errorf("%s: package store is not a directory", packageName)
	}
	data, err := os.ReadFile(filepath.Join(store, metaFile))
	if err != nil {
		return value, false, fmt.Errorf("%s: read metadata: %w", packageName, err)
	}
	if err := json.Unmarshal(data, &value); err != nil {
		return value, false, fmt.Errorf("%s: read metadata: %w", packageName, err)
	}
	if value.Digest == "" {
		return value, false, fmt.Errorf("%s: metadata has no digest", packageName)
	}
	for _, target := range value.LinkTo {
		clean, err := cleanLinkTo(target)
		if err != nil || clean == "" || clean != target {
			return value, false, fmt.Errorf("%s: metadata has invalid link target %q", packageName, target)
		}
	}
	return value, true, nil
}

func writeMetadata(store string, value metadata) error {
	data, err := json.Marshal(value)
	if err != nil {
		return err
	}
	temporary := filepath.Join(store, metaFile+".tmp")
	if err := os.WriteFile(temporary, data, 0o644); err != nil {
		return err
	}
	return os.Rename(temporary, filepath.Join(store, metaFile))
}

func extractTarGz(filename, destination, packageName string) error {
	file, err := os.Open(filename)
	if err != nil {
		return err
	}
	defer file.Close()
	compressed, err := gzip.NewReader(file)
	if err != nil {
		return err
	}
	defer compressed.Close()
	root, err := os.OpenRoot(destination)
	if err != nil {
		return err
	}
	defer root.Close()

	archive := tar.NewReader(compressed)
	for {
		header, err := archive.Next()
		if err == io.EOF {
			return nil
		}
		if err != nil {
			return err
		}
		name, err := archivePath(header.Name, packageName)
		if err != nil {
			return err
		}
		if name == "" {
			continue
		}
		if name == metaFile {
			return fmt.Errorf("archive contains reserved path %s", header.Name)
		}
		if err := root.MkdirAll(filepath.Dir(name), 0o755); err != nil {
			return fmt.Errorf("extract %s: %w", header.Name, err)
		}

		switch header.Typeflag {
		case tar.TypeDir:
			err = root.MkdirAll(name, 0o755)
		case tar.TypeReg, tar.TypeRegA:
			if info, statErr := root.Lstat(name); statErr == nil && info.Mode()&os.ModeSymlink != 0 {
				err = fmt.Errorf("file replaces symlink")
			} else if statErr != nil && !os.IsNotExist(statErr) {
				err = statErr
			} else {
				err = writeArchiveFile(root, name, os.FileMode(header.Mode)&0o777, archive)
			}
		case tar.TypeSymlink:
			if err = validateSymlink(name, header.Linkname); err == nil {
				if removeErr := root.Remove(name); removeErr != nil && !os.IsNotExist(removeErr) {
					err = removeErr
				} else {
					err = root.Symlink(filepath.FromSlash(header.Linkname), name)
				}
			}
		case tar.TypeLink:
			var target string
			target, err = archivePath(header.Linkname, packageName)
			if err == nil && target == "" {
				err = fmt.Errorf("hardlink points to archive root")
			}
			if err == nil {
				err = root.Link(target, name)
			}
		default:
			err = fmt.Errorf("unsupported tar entry type %d", header.Typeflag)
		}
		if err != nil {
			return fmt.Errorf("extract %s: %w", header.Name, err)
		}
	}
}

func archivePath(name, packageName string) (string, error) {
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

func validateSymlink(name, target string) error {
	if path.IsAbs(target) {
		return fmt.Errorf("absolute symlink target")
	}
	resolved := path.Clean(path.Join(path.Dir(filepath.ToSlash(name)), target))
	if resolved == ".." || strings.HasPrefix(resolved, "../") {
		return fmt.Errorf("symlink target escapes package")
	}
	return nil
}

func writeArchiveFile(root *os.Root, name string, mode os.FileMode, source io.Reader) error {
	file, err := root.OpenFile(name, os.O_CREATE|os.O_TRUNC|os.O_WRONLY, mode)
	if err != nil {
		return err
	}
	_, copyErr := io.Copy(file, source)
	return errors.Join(copyErr, file.Close())
}

func packageFiles(store string) ([]string, error) {
	var files []string
	err := fs.WalkDir(os.DirFS(store), ".", func(name string, entry fs.DirEntry, err error) error {
		if err != nil || name == "." || entry.IsDir() {
			return err
		}
		if name != metaFile && name != metaFile+".tmp" {
			files = append(files, filepath.FromSlash(name))
		}
		return nil
	})
	return files, err
}

func linkPackage(prefix, packageName, linkTo string) error {
	files, err := packageFiles(storePath(prefix, packageName))
	if err != nil {
		return err
	}
	root, err := os.OpenRoot(prefix)
	if err != nil {
		return err
	}
	defer root.Close()
	if err := root.MkdirAll(linkTo, 0o755); err != nil {
		return err
	}
	for _, name := range files {
		destination := filepath.Join(linkTo, name)
		if destination == "store" || strings.HasPrefix(destination, "store"+string(os.PathSeparator)) {
			return fmt.Errorf("package path %s overlaps store", name)
		}
		if err := root.MkdirAll(filepath.Dir(destination), 0o755); err != nil {
			return err
		}
		target, err := filepath.Rel(filepath.Dir(destination), filepath.Join("store", packageName, name))
		if err != nil {
			return err
		}
		if info, err := root.Lstat(destination); err == nil {
			if info.Mode()&os.ModeSymlink == 0 {
				return fmt.Errorf("refusing to replace non-symlink %s", filepath.Join(prefix, destination))
			}
			current, err := root.Readlink(destination)
			if err != nil || current == target {
				if err != nil {
					return err
				}
				continue
			}
			if err := root.Remove(destination); err != nil {
				return err
			}
		} else if !os.IsNotExist(err) {
			return err
		}
		if err := root.Symlink(target, destination); err != nil {
			return err
		}
	}
	return nil
}

func unlinkPackage(prefix, packageName string, targets []string) error {
	files, err := packageFiles(storePath(prefix, packageName))
	if err != nil {
		return err
	}
	root, err := os.OpenRoot(prefix)
	if err != nil {
		return err
	}
	defer root.Close()
	for _, linkTo := range targets {
		for _, name := range files {
			destination := filepath.Join(linkTo, name)
			target, err := filepath.Rel(filepath.Dir(destination), filepath.Join("store", packageName, name))
			if err != nil {
				return err
			}
			current, err := root.Readlink(destination)
			if os.IsNotExist(err) || errors.Is(err, unix.EINVAL) {
				continue
			}
			if err != nil {
				return err
			}
			if current == target {
				if err := root.Remove(destination); err != nil {
					return err
				}
			}
		}
	}
	return nil
}

func replaceStore(prefix, packageName, staged string) error {
	store := storePath(prefix, packageName)
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
	if err := ensureStore(prefix); err != nil {
		return err
	}
	lock, err := os.OpenFile(filepath.Join(storeRoot(prefix), ".lock"), os.O_CREATE|os.O_RDWR, 0o600)
	if err != nil {
		return err
	}
	if err := unix.Flock(int(lock.Fd()), unix.LOCK_EX); err != nil {
		_ = lock.Close()
		return err
	}
	operationErr := operation()
	unlockErr := unix.Flock(int(lock.Fd()), unix.LOCK_UN)
	return errors.Join(operationErr, unlockErr, lock.Close())
}

func ensureStore(prefix string) error {
	if err := os.MkdirAll(prefix, 0o755); err != nil {
		return err
	}
	root, err := os.OpenRoot(prefix)
	if err != nil {
		return err
	}
	defer root.Close()
	if err := root.Mkdir("store", 0o755); err != nil && !os.IsExist(err) {
		return err
	}
	info, err := root.Lstat("store")
	if err != nil {
		return err
	}
	if !info.IsDir() || info.Mode()&os.ModeSymlink != 0 {
		return fmt.Errorf("%s is not a real directory", storeRoot(prefix))
	}
	return nil
}
