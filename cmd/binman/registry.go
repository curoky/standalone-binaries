package main

import (
	"context"
	"errors"
	"fmt"
	"net/http"
	"os"

	"github.com/google/go-containerregistry/pkg/authn"
	"github.com/google/go-containerregistry/pkg/name"
	v1 "github.com/google/go-containerregistry/pkg/v1"
	"github.com/google/go-containerregistry/pkg/v1/remote"
	"github.com/google/go-containerregistry/pkg/v1/remote/transport"
	"github.com/google/go-containerregistry/pkg/v1/types"
	"golang.org/x/sync/errgroup"
)

type artifact struct {
	Name   string
	Layer  v1.Layer
	Digest string
}

func (c *client) resolve(ctx context.Context, names []string, arch string) ([]artifact, error) {
	puller, err := remote.NewPuller(
		remote.WithAuth(authn.Anonymous),
		remote.WithContext(ctx),
		remote.WithJobs(downloadParallel),
	)
	if err != nil {
		return nil, err
	}

	artifacts := make([]artifact, len(names))
	errs := make([]error, len(names))
	var group errgroup.Group
	group.SetLimit(resolveParallel)
	for index, packageName := range names {
		group.Go(func() error {
			artifacts[index], errs[index] = c.resolveOne(packageName, arch, puller)
			return nil
		})
	}
	_ = group.Wait()
	return artifacts, errors.Join(errs...)
}

func (c *client) resolveOne(packageName, arch string, puller *remote.Puller) (artifact, error) {
	result := artifact{Name: packageName}
	reference, err := name.ParseReference(
		fmt.Sprintf("%s:%s-%s", c.registry, packageName, arch),
		name.StrictValidation,
	)
	if err != nil {
		return result, err
	}
	image, err := remote.Image(reference, remote.Reuse(puller))
	if err != nil {
		var transportError *transport.Error
		if errors.As(err, &transportError) && transportError.StatusCode == http.StatusNotFound {
			return result, fmt.Errorf("%s: not found for %s", packageName, arch)
		}
		return result, fmt.Errorf("%s: %w", packageName, err)
	}
	layers, err := image.Layers()
	if err != nil {
		return result, fmt.Errorf("%s: read manifest: %w", packageName, err)
	}
	if len(layers) != 1 {
		return result, fmt.Errorf("%s: manifest has %d layers, expected 1", packageName, len(layers))
	}
	mediaType, err := layers[0].MediaType()
	if err != nil {
		return result, fmt.Errorf("%s: read layer media type: %w", packageName, err)
	}
	if mediaType != types.OCILayer {
		return result, fmt.Errorf("%s: layer media type is %q, expected %q", packageName, mediaType, types.OCILayer)
	}
	digest, err := layers[0].Digest()
	if err != nil {
		return result, fmt.Errorf("%s: read layer digest: %w", packageName, err)
	}
	result.Layer = layers[0]
	result.Digest = digest.String()
	return result, nil
}

func downloadArtifact(value artifact, destination string) error {
	reader, err := value.Layer.Compressed()
	if err != nil {
		return err
	}
	file, err := os.OpenFile(destination, os.O_CREATE|os.O_EXCL|os.O_WRONLY, 0o600)
	if err != nil {
		_ = reader.Close()
		return err
	}
	_, copyErr := file.ReadFrom(reader)
	closeErr := file.Close()
	return errors.Join(copyErr, closeErr, reader.Close())
}
