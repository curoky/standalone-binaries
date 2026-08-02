package main

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"

	ocispec "github.com/opencontainers/image-spec/specs-go/v1"
	"oras.land/oras-go/v2/errdef"
)

const artifactRepository = "ghcr.io/curoky/standalone-binaries"
const publicationSystem = "dev.curoky.standalone.system"
const publicationOut = "dev.curoky.standalone.out-path"
const publicationArchive = "dev.curoky.standalone.archive-path"
const archiveMediaType = "application/vnd.oci.image.layer.v1.tar+gzip"

func publicationReady(ctx context.Context, client *registryClient, tag, system, out, archive string) (bool, error) {
	if _, err := storeHash(out); err != nil {
		return false, err
	}
	if _, err := storeHash(archive); err != nil {
		return false, err
	}
	return registryRequest(ctx, "check publication "+tag, func(ctx context.Context) (bool, error) {
		descriptor, reader, err := client.repo.FetchReference(ctx, tag)
		if errors.Is(err, errdef.ErrNotFound) || isNameUnknown(err) {
			return false, nil
		}
		if err != nil {
			return false, err
		}
		defer reader.Close()
		body, err := readMetadata(reader, descriptor)
		if err != nil {
			return false, err
		}
		var manifest ocispec.Manifest
		if err := json.Unmarshal(body, &manifest); err != nil {
			return false, err
		}
		if manifest.SchemaVersion != 2 || len(manifest.Layers) != 1 || manifest.Layers[0].MediaType != archiveMediaType || manifest.Layers[0].Size <= 0 || manifest.Layers[0].Digest.Validate() != nil {
			return false, fmt.Errorf("invalid publication manifest %s", tag)
		}
		if manifest.Annotations[publicationSystem] != system || manifest.Annotations[publicationOut] != out || manifest.Annotations[publicationArchive] != archive {
			return false, nil
		}
		return client.repo.Blobs().Exists(ctx, manifest.Layers[0])
	})
}
