package main

import (
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"time"
)

type installOpts struct {
	prefix string
	arch   string
	linked bool
	force  bool
}

type installTarget struct {
	name   string
	arch   string
	linked bool
}

type installJob struct {
	packageArtifact
	linked  bool
	current *meta
	fetch   bool
}

func (c *client) installPackages(names []string, options installOpts) error {
	plan := make([]installTarget, 0, len(names))
	seen := make(map[string]bool, len(names))
	for _, packageName := range names {
		if !seen[packageName] {
			seen[packageName] = true
			plan = append(plan, installTarget{name: packageName, arch: options.arch, linked: options.linked})
		}
	}
	return c.installPackagePlan(plan, options.prefix, options.arch, options.force)
}

func (c *client) installPackagePlan(plan []installTarget, prefix, arch string, force bool) error {
	if arch != "" {
		if err := validateArch(arch); err != nil {
			return err
		}
	}
	requests := make([]artifactRequest, len(plan))
	for index, target := range plan {
		if err := validatePackageName(target.name); err != nil {
			return err
		}
		if target.arch == "" {
			target.arch = arch
		}
		if err := validateArch(target.arch); err != nil {
			return fmt.Errorf("%s: %w", target.name, err)
		}
		requests[index] = artifactRequest{name: target.name, arch: target.arch}
	}
	start := time.Now()
	c.logger.Info("install started", "count", len(plan), "prefix", prefix, "force", force)
	fmt.Fprintf(c.output, "> Resolving %d package(s)...\n", len(plan))
	artifacts, err := c.resolveArtifacts(requests)
	if err != nil {
		c.logger.Error("install aborted: unresolved packages", "err", err)
		return fmt.Errorf("aborting, some packages could not be resolved:\n%w", err)
	}
	jobs, downloads, err := c.prepareInstallJobs(prefix, plan, artifacts, force)
	if err != nil {
		return err
	}
	if len(downloads) > 0 {
		fmt.Fprintf(c.output, "> Downloading %d package(s)...\n", len(downloads))
		if err := downloadArtifacts(downloads); err != nil {
			return fmt.Errorf("download failed: %w", err)
		}
	}
	// Package links share a prefix, so commit in manifest order.
	for _, job := range jobs {
		if err := c.applyInstallJob(prefix, job); err != nil {
			return err
		}
	}
	total := time.Since(start)
	skipped := len(jobs) - len(downloads)
	c.logger.Info("install finished", "installed", len(downloads), "skipped", skipped, "took", total.String())
	fmt.Fprintf(c.output, "> Done: %d installed, %d up-to-date in %s.\n",
		len(downloads), skipped, total.Round(time.Millisecond))
	return nil
}

func (c *client) prepareInstallJobs(prefix string, plan []installTarget, artifacts []packageArtifact, force bool) ([]installJob, []artifactDownload, error) {
	jobs := make([]installJob, len(artifacts))
	var downloads []artifactDownload
	for index, artifact := range artifacts {
		job := installJob{packageArtifact: artifact, linked: plan[index].linked}
		if metadata, err := readMeta(prefix, job.name); err == nil {
			job.current = &metadata
		} else if _, statErr := os.Stat(storePath(prefix, job.name)); statErr == nil {
			// Invalid metadata denotes an interrupted install that must be replaced.
			if err := os.RemoveAll(storePath(prefix, job.name)); err != nil {
				return nil, nil, fmt.Errorf("%s: clean leftover store: %w", job.name, err)
			}
		} else if !os.IsNotExist(statErr) {
			return nil, nil, statErr
		}
		job.fetch = force || job.current == nil || job.current.Digest != job.digest
		if job.fetch {
			downloads = append(downloads, artifactDownload{packageArtifact: artifact, destination: cachePath(job.arch, job.name)})
		} else {
			fmt.Fprintf(c.output, "> %s (%s) is already up to date, skipping download. Use --force to reinstall.\n", job.name, job.arch)
		}
		jobs[index] = job
	}
	return jobs, downloads, nil
}

func (c *client) applyInstallJob(prefix string, job installJob) error {
	currentLinked := job.current != nil && job.current.Linked
	nextMeta := meta{Name: job.name, Arch: job.arch, Digest: job.digest, Linked: job.linked}
	if !job.fetch {
		if currentLinked && !job.linked {
			if err := unlinkPkg(prefix, job.name); err != nil {
				return fmt.Errorf("%s: unlink failed: %w", job.name, err)
			}
		}
		if job.linked {
			if err := linkPkg(prefix, job.name); err != nil {
				return fmt.Errorf("%s: link failed: %w", job.name, err)
			}
		}
		if job.current.Arch != job.arch || job.current.Linked != job.linked {
			return writeMeta(prefix, nextMeta)
		}
		return nil
	}

	store := storePath(prefix, job.name)
	fmt.Fprintf(c.output, "> Installing %s (%s) -> %s (linked=%t)\n", job.name, job.arch, store, job.linked)
	parent := filepath.Dir(store)
	if err := os.MkdirAll(parent, 0o755); err != nil {
		return err
	}
	staged, err := os.MkdirTemp(parent, "."+job.name+".stage-")
	if err != nil {
		return err
	}
	defer os.RemoveAll(staged)
	if err := extractTarGz(cachePath(job.arch, job.name), staged); err != nil {
		return fmt.Errorf("%s: extract failed: %w", job.name, err)
	}
	if err := writeMetaAt(staged, nextMeta); err != nil {
		return err
	}
	if err := placeStore(prefix, job.name, staged, currentLinked, job.linked); err != nil {
		return err
	}
	fmt.Fprintf(c.output, "> Installed %s.\n", job.name)
	return nil
}

func (c *client) cmdRemove(prefix, packageName string) error {
	if err := validatePackageName(packageName); err != nil {
		return err
	}
	store := storePath(prefix, packageName)
	if _, err := os.Stat(store); os.IsNotExist(err) {
		return fmt.Errorf("%s is not installed", packageName)
	} else if err != nil {
		return err
	}
	metadata, err := readMeta(prefix, packageName)
	if err != nil {
		return fmt.Errorf("%s: read metadata: %w", packageName, err)
	}
	files := make(packageFiles)
	unlink := func(root string) error {
		entries, err := files.get(store)
		if err != nil {
			return err
		}
		return unlinkFilesFrom(entries, root)
	}
	if metadata.Linked {
		if err := unlink(prefix); err != nil {
			return err
		}
	}
	profiles, err := os.ReadDir(filepath.Join(prefix, "profile"))
	if err != nil && !os.IsNotExist(err) {
		return err
	}
	for _, profile := range profiles {
		if profile.IsDir() {
			if err := unlink(filepath.Join(prefix, "profile", profile.Name())); err != nil {
				return err
			}
		}
	}
	if err := os.RemoveAll(store); err != nil {
		return err
	}
	fmt.Fprintf(c.output, "> Removed %s from %s.\n", packageName, prefix)
	return nil
}

func installedNames(prefix string) ([]string, error) {
	entries, err := os.ReadDir(filepath.Join(prefix, "store"))
	if os.IsNotExist(err) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	var names []string
	for _, entry := range entries {
		if entry.IsDir() {
			if _, err := os.Stat(metaPath(prefix, entry.Name())); err == nil {
				names = append(names, entry.Name())
			} else if !os.IsNotExist(err) {
				return nil, err
			}
		}
	}
	return names, nil
}

func (c *client) cmdList(prefix string) error {
	names, err := installedNames(prefix)
	if err != nil {
		return err
	}
	if len(names) == 0 {
		fmt.Fprintf(c.output, "No packages installed under %s.\n", prefix)
		return nil
	}
	fmt.Fprintf(c.output, "%-22s %-15s %-7s %s\n", "NAME", "ARCH", "LINKED", "DIGEST")
	for _, packageName := range names {
		metadata, err := readMeta(prefix, packageName)
		if err != nil {
			return fmt.Errorf("%s: read metadata: %w", packageName, err)
		}
		linked := "0"
		if metadata.Linked {
			linked = "1"
		}
		fmt.Fprintf(c.output, "%-22s %-15s %-7s %s\n", metadata.Name, metadata.Arch, linked, short(metadata.Digest))
	}
	return nil
}

func (c *client) cmdSearch(arch, query string) error {
	names, err := c.remotePackageNames(arch)
	if err != nil {
		return err
	}
	for _, packageName := range matchingPackageNames(names, query) {
		fmt.Fprintln(c.output, packageName)
	}
	return nil
}

func (c *client) cmdListAvailable(arch string) error {
	names, err := c.remotePackageNames(arch)
	if err != nil {
		return err
	}
	for _, packageName := range names {
		fmt.Fprintln(c.output, packageName)
	}
	return nil
}

func matchingPackageNames(names []string, query string) []string {
	query = strings.ToLower(query)
	matches := make([]string, 0, len(names))
	for _, packageName := range names {
		if strings.Contains(strings.ToLower(packageName), query) {
			matches = append(matches, packageName)
		}
	}
	return matches
}

func (c *client) cmdInfo(prefix, arch, packageName string) error {
	if err := validatePackageName(packageName); err != nil {
		return err
	}
	if err := validateArch(arch); err != nil {
		return err
	}
	metadata, metadataError := readMeta(prefix, packageName)
	if metadataError != nil && !os.IsNotExist(metadataError) {
		return fmt.Errorf("%s: read metadata: %w", packageName, metadataError)
	}
	fmt.Fprintf(c.output, "Package: %s\n", packageName)
	fmt.Fprintf(c.output, "Registry: %s\n", c.ref(packageName, arch))
	remote, remoteError := c.remoteDigest(packageName, arch)
	if metadataError == nil {
		fmt.Fprintf(c.output, "Status:  installed (%s)\n", storePath(prefix, packageName))
		fmt.Fprintf(c.output, "  arch:    %s\n", metadata.Arch)
		fmt.Fprintf(c.output, "  digest:  %s\n", metadata.Digest)
		fmt.Fprintf(c.output, "  linked:  %t\n", metadata.Linked)
		fmt.Fprintf(c.output, "  installed_at: %s\n", metadata.InstalledAt)
		switch {
		case remoteError != nil:
			fmt.Fprintf(c.output, "  remote:  <error: %v>\n", remoteError)
		case metadata.Digest == remote:
			fmt.Fprintf(c.output, "  remote:  %s (up to date)\n", remote)
		default:
			fmt.Fprintf(c.output, "  remote:  %s (outdated)\n", remote)
		}
		return nil
	}
	fmt.Fprintln(c.output, "Status:  not installed")
	if remoteError != nil {
		return remoteError
	}
	fmt.Fprintf(c.output, "  remote:  %s\n", remote)
	return nil
}

func (c *client) cmdOutdated(prefix string) error {
	names, err := installedNames(prefix)
	if err != nil {
		return err
	}
	if len(names) == 0 {
		fmt.Fprintf(c.output, "No packages installed under %s.\n", prefix)
		return nil
	}
	metas := make([]meta, len(names))
	requests := make([]artifactRequest, len(names))
	resolveErrors := make([]error, len(names))
	for index, packageName := range names {
		metadata, err := readMeta(prefix, packageName)
		if err != nil {
			resolveErrors[index] = fmt.Errorf("%s: read metadata: %w", packageName, err)
			continue
		}
		metas[index] = metadata
		requests[index] = artifactRequest{name: packageName, arch: metadata.Arch}
	}
	if err := errors.Join(resolveErrors...); err != nil {
		return fmt.Errorf("could not check all packages:\n%w", err)
	}
	artifacts, err := c.resolveArtifacts(requests)
	if err != nil {
		return fmt.Errorf("could not check all packages:\n%w", err)
	}
	outdated := false
	for index, packageName := range names {
		if metas[index].Digest != artifacts[index].digest {
			outdated = true
			fmt.Fprintf(c.output, "%-22s %s -> %s\n", packageName, short(metas[index].Digest), short(artifacts[index].digest))
		}
	}
	if !outdated {
		fmt.Fprintln(c.output, "All packages are up to date.")
	}
	return nil
}

func (c *client) cmdUpgrade(prefix, arch string, names []string) error {
	if len(names) == 0 {
		var err error
		names, err = installedNames(prefix)
		if err != nil {
			return err
		}
		if len(names) == 0 {
			fmt.Fprintf(c.output, "No packages installed under %s.\n", prefix)
			return nil
		}
	}
	plan := make([]installTarget, 0, len(names))
	seen := make(map[string]bool, len(names))
	for _, packageName := range names {
		if err := validatePackageName(packageName); err != nil {
			return err
		}
		if seen[packageName] {
			continue
		}
		seen[packageName] = true
		metadata, err := readMeta(prefix, packageName)
		if err != nil {
			if os.IsNotExist(err) {
				return fmt.Errorf("%s is not installed", packageName)
			}
			return fmt.Errorf("%s: read metadata: %w", packageName, err)
		}
		targetArch := metadata.Arch
		if arch != "" {
			targetArch = arch
		}
		plan = append(plan, installTarget{name: packageName, arch: targetArch, linked: metadata.Linked})
	}
	return c.installPackagePlan(plan, prefix, arch, false)
}

func short(digest string) string { return digest[:min(len(digest), 19)] }
