package main

import (
	"context"
	"fmt"
	"os"
	"path/filepath"
	"runtime"

	"golang.org/x/sync/errgroup"
)

type installJob struct {
	Artifact artifact
	LinkTo   []string
	Archive  string
	Staged   string
	Changed  bool
}

func (c *client) install(ctx context.Context, prefix string, plan installPlan) error {
	prefix, err := filepath.Abs(prefix)
	if err != nil {
		return fmt.Errorf("resolve prefix: %w", err)
	}
	arch, err := detectArch()
	if err != nil {
		return err
	}

	fmt.Fprintf(c.output, "> Resolving %d package(s)...\n", len(plan.Packages))
	artifacts, err := c.resolve(ctx, plan.Packages, arch)
	if err != nil {
		return fmt.Errorf("resolve packages: %w", err)
	}
	jobs := make([]installJob, len(artifacts))
	changed := 0
	for index, value := range artifacts {
		current, installed, err := readMetadata(prefix, value.Name)
		if err != nil {
			return err
		}
		jobs[index] = installJob{
			Artifact: value,
			LinkTo:   plan.LinkTo[value.Name],
			Changed:  !installed || current.Digest != value.Digest,
		}
		if jobs[index].Changed {
			changed++
		}
	}

	if err := ensureStore(prefix); err != nil {
		return err
	}
	workspace, err := os.MkdirTemp(storeRoot(prefix), ".install-")
	if err != nil {
		return err
	}
	defer os.RemoveAll(workspace)

	if changed > 0 {
		fmt.Fprintf(c.output, "> Downloading %d package(s)...\n", changed)
		if err := runParallel(len(jobs), downloadParallel, func(index int) error {
			if !jobs[index].Changed {
				return nil
			}
			jobs[index].Archive = filepath.Join(workspace, jobs[index].Artifact.Name+".tar.gz")
			if err := downloadArtifact(jobs[index].Artifact, jobs[index].Archive); err != nil {
				return fmt.Errorf("%s: download: %w", jobs[index].Artifact.Name, err)
			}
			return nil
		}); err != nil {
			return err
		}

		fmt.Fprintf(c.output, "> Extracting %d package(s)...\n", changed)
		if err := runParallel(len(jobs), runtime.GOMAXPROCS(0), func(index int) error {
			job := &jobs[index]
			if !job.Changed {
				return nil
			}
			job.Staged = filepath.Join(workspace, job.Artifact.Name)
			if err := os.Mkdir(job.Staged, 0o755); err != nil {
				return fmt.Errorf("%s: create staging directory: %w", job.Artifact.Name, err)
			}
			if err := extractTarGz(job.Archive, job.Staged, job.Artifact.Name); err != nil {
				return fmt.Errorf("%s: extract: %w", job.Artifact.Name, err)
			}
			if err := writeMetadata(job.Staged, metadata{Digest: job.Artifact.Digest, LinkTo: job.LinkTo}); err != nil {
				return fmt.Errorf("%s: write metadata: %w", job.Artifact.Name, err)
			}
			return os.Remove(job.Archive)
		}); err != nil {
			return err
		}
	}

	if err := withPrefixLock(prefix, func() error {
		return commitInstall(prefix, jobs, plan.Links)
	}); err != nil {
		return err
	}
	fmt.Fprintf(c.output, "> Installed %d package(s); %d downloaded.\n", len(jobs), changed)
	return nil
}

func runParallel(count, limit int, operation func(int) error) error {
	var group errgroup.Group
	group.SetLimit(max(1, limit))
	for index := range count {
		group.Go(func() error { return operation(index) })
	}
	return group.Wait()
}

func commitInstall(prefix string, jobs []installJob, links []linkOperation) error {
	current := make([]metadata, len(jobs))
	installed := make([]bool, len(jobs))
	for index, job := range jobs {
		var err error
		current[index], installed[index], err = readMetadata(prefix, job.Artifact.Name)
		if err != nil {
			return err
		}
		if !job.Changed && (!installed[index] || current[index].Digest != job.Artifact.Digest) {
			return fmt.Errorf("%s changed during installation; retry", job.Artifact.Name)
		}
	}

	for index, job := range jobs {
		if installed[index] {
			if err := unlinkPackage(prefix, job.Artifact.Name, current[index].LinkTo); err != nil {
				return fmt.Errorf("%s: unlink: %w", job.Artifact.Name, err)
			}
		}
		if job.Changed {
			if err := replaceStore(prefix, job.Artifact.Name, job.Staged); err != nil {
				return fmt.Errorf("%s: replace store: %w", job.Artifact.Name, err)
			}
		} else if err := writeMetadata(storePath(prefix, job.Artifact.Name), metadata{
			Digest: job.Artifact.Digest,
			LinkTo: job.LinkTo,
		}); err != nil {
			return fmt.Errorf("%s: write metadata: %w", job.Artifact.Name, err)
		}
	}

	for _, operation := range links {
		if err := linkPackage(prefix, operation.Package, operation.Root); err != nil {
			return fmt.Errorf("%s: link to %s: %w", operation.Package, operation.Root, err)
		}
	}
	return nil
}

func (c *client) remove(prefix string, names []string) error {
	prefix, err := filepath.Abs(prefix)
	if err != nil {
		return fmt.Errorf("resolve prefix: %w", err)
	}
	unique := make([]string, 0, len(names))
	seen := make(map[string]bool)
	for _, packageName := range names {
		if err := validatePackageName(packageName); err != nil {
			return err
		}
		if !seen[packageName] {
			seen[packageName] = true
			unique = append(unique, packageName)
		}
	}
	return withPrefixLock(prefix, func() error {
		metas := make([]metadata, len(unique))
		for index, packageName := range unique {
			var installed bool
			metas[index], installed, err = readMetadata(prefix, packageName)
			if err != nil {
				return err
			}
			if !installed {
				return fmt.Errorf("%s is not installed", packageName)
			}
		}
		for index, packageName := range unique {
			if err := unlinkPackage(prefix, packageName, metas[index].LinkTo); err != nil {
				return fmt.Errorf("%s: unlink: %w", packageName, err)
			}
			if err := os.RemoveAll(storePath(prefix, packageName)); err != nil {
				return fmt.Errorf("%s: remove store: %w", packageName, err)
			}
			fmt.Fprintf(c.output, "> Removed %s.\n", packageName)
		}
		return nil
	})
}
