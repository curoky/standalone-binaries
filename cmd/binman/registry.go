package main

import (
	"errors"
	"fmt"
	"net/http"
	"os"
	"path/filepath"
	"slices"
	"strings"

	"github.com/google/go-containerregistry/pkg/authn"
	"github.com/google/go-containerregistry/pkg/name"
	v1 "github.com/google/go-containerregistry/pkg/v1"
	"github.com/google/go-containerregistry/pkg/v1/remote"
	"github.com/google/go-containerregistry/pkg/v1/remote/transport"
	"golang.org/x/sync/errgroup"
)

func (c *client) ref(packageName, arch string) string {
	return fmt.Sprintf("%s:%s-%s", c.registry, packageName, arch)
}

func (c *client) remotePackageNames(arch string) ([]string, error) {
	if err := validateArch(arch); err != nil {
		return nil, err
	}
	repository, err := name.NewRepository(c.registry, name.StrictValidation)
	if err != nil {
		return nil, err
	}
	tags, err := remote.List(repository, remote.WithAuth(authn.Anonymous))
	if err != nil {
		return nil, fmt.Errorf("list packages: %w", err)
	}
	return packageNamesFromTags(tags, arch), nil
}

func packageNamesFromTags(tags []string, arch string) []string {
	suffix := "-" + arch
	names := make([]string, 0, len(tags))
	for _, tag := range tags {
		packageName, ok := strings.CutSuffix(tag, suffix)
		if ok && validatePackageName(packageName) == nil {
			names = append(names, packageName)
		}
	}
	slices.Sort(names)
	return slices.Compact(names)
}

func isNotFound(err error) bool {
	var transportError *transport.Error
	return errors.As(err, &transportError) && transportError.StatusCode == http.StatusNotFound
}

type artifactRequest struct {
	name string
	arch string
}

type packageArtifact struct {
	name   string
	arch   string
	layer  v1.Layer
	digest string
}

type artifactDownload struct {
	packageArtifact
	destination string
}

func (c *client) resolveArtifact(request artifactRequest, puller *remote.Puller) (packageArtifact, error) {
	artifact := packageArtifact{name: request.name, arch: request.arch}
	if err := validatePackageName(request.name); err != nil {
		return artifact, err
	}
	if err := validateArch(request.arch); err != nil {
		return artifact, err
	}
	reference, err := name.ParseReference(c.ref(request.name, request.arch), name.StrictValidation)
	if err != nil {
		return artifact, fmt.Errorf("%s: %w", request.name, err)
	}
	image, err := remote.Image(reference, remote.Reuse(puller))
	if err != nil {
		if isNotFound(err) {
			return artifact, fmt.Errorf("%s: not found for arch %q", request.name, request.arch)
		}
		return artifact, fmt.Errorf("%s: %w", request.name, err)
	}
	layers, err := image.Layers()
	if err != nil {
		return artifact, fmt.Errorf("%s: %w", request.name, err)
	}
	if len(layers) == 0 {
		return artifact, fmt.Errorf("%s: image has no layers", request.name)
	}
	artifact.layer = layers[len(layers)-1]
	digest, err := artifact.layer.Digest()
	if err != nil {
		return artifact, fmt.Errorf("%s: %w", request.name, err)
	}
	artifact.digest = digest.String()
	return artifact, nil
}

func (c *client) remoteDigest(packageName, arch string) (string, error) {
	artifacts, err := c.resolveArtifacts([]artifactRequest{{name: packageName, arch: arch}})
	if err != nil {
		return "", err
	}
	return artifacts[0].digest, nil
}

func (c *client) resolveArtifacts(requests []artifactRequest) ([]packageArtifact, error) {
	puller, err := remote.NewPuller(remote.WithAuth(authn.Anonymous), remote.WithJobs(maxParallel))
	if err != nil {
		return nil, err
	}
	artifacts := make([]packageArtifact, len(requests))
	resolveErrors := make([]error, len(requests))
	var group errgroup.Group
	group.SetLimit(maxParallel)
	for index, request := range requests {
		group.Go(func() error {
			artifacts[index], resolveErrors[index] = c.resolveArtifact(request, puller)
			return nil
		})
	}
	// Each error is collected in request order, not goroutine completion order.
	_ = group.Wait()
	return artifacts, errors.Join(resolveErrors...)
}

func downloadArtifacts(downloads []artifactDownload) error {
	var group errgroup.Group
	group.SetLimit(maxParallel)
	for _, download := range downloads {
		group.Go(func() error {
			if err := downloadLayer(download.layer, download.destination); err != nil {
				return fmt.Errorf("%s: %w", download.name, err)
			}
			return nil
		})
	}
	return group.Wait()
}

func downloadLayer(layer v1.Layer, dst string) error {
	reader, err := layer.Compressed()
	if err != nil {
		return err
	}
	defer reader.Close()
	return writeAtomic(dst, 0o600, reader)
}

func cachePath(arch, packageName string) string {
	base := os.Getenv("XDG_CACHE_HOME")
	if base == "" {
		base = filepath.Join(os.Getenv("HOME"), ".cache")
	}
	return filepath.Join(base, "binman", arch, packageName+".tar.gz")
}
