package main

import (
	"bytes"
	"cmp"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"path"
	"slices"
	"strings"
	"time"

	"github.com/nix-community/go-nix/pkg/narinfo"
	"github.com/opencontainers/go-digest"
	"github.com/opencontainers/image-spec/specs-go"
	ocispec "github.com/opencontainers/image-spec/specs-go/v1"
	"golang.org/x/sync/errgroup"
	"oras.land/oras-go/v2"
	"oras.land/oras-go/v2/content"
	"oras.land/oras-go/v2/errdef"
	"oras.land/oras-go/v2/registry"
	"oras.land/oras-go/v2/registry/remote"
	"oras.land/oras-go/v2/registry/remote/auth"
	"oras.land/oras-go/v2/registry/remote/credentials"
	"oras.land/oras-go/v2/registry/remote/errcode"
	"oras.land/oras-go/v2/registry/remote/retry"
)

const (
	storeHashAnnotation     = "org.nixos.store.hash"
	registryTimeout         = 30 * time.Second
	registryTimeoutAttempts = 3
	segmentLoadConcurrency  = 32
	maxMetadataSize         = 64 << 20
)

type registryClient struct {
	repo *remote.Repository
}

func newRegistryClient(repository string, insecure bool) (*registryClient, error) {
	repo, err := remote.NewRepository(repository)
	if err != nil {
		return nil, fmt.Errorf("parse cache repository: %w", err)
	}
	repo.PlainHTTP = insecure

	var credential auth.CredentialFunc
	var authSource string
	if token := os.Getenv("GITHUB_TOKEN"); token != "" {
		username := os.Getenv("GITHUB_ACTOR")
		if username == "" {
			username = "token"
		}
		credential = auth.StaticCredential(repo.Reference.Registry, auth.Credential{
			Username: username,
			Password: token,
		})
		authSource = fmt.Sprintf("GITHUB_TOKEN (user %q)", username)
	} else {
		store, err := credentials.NewStoreFromDocker(credentials.StoreOptions{})
		if err != nil {
			return nil, fmt.Errorf("load registry credentials: %w", err)
		}
		credential = credentials.Credential(store)
		authSource = "docker credential store"
	}
	transport := http.DefaultTransport.(*http.Transport).Clone()
	transport.MaxIdleConnsPerHost = segmentLoadConcurrency
	repo.Client = &auth.Client{
		Client:     &http.Client{Transport: retry.NewTransport(transport)},
		Cache:      auth.NewCache(),
		Credential: credential,
		Header:     auth.DefaultClient.Header.Clone(),
	}
	log.Printf("cache client: repo=%s registry=%s plain-http=%t auth=%s",
		repo.Reference.Repository, repo.Reference.Registry, repo.PlainHTTP, authSource)
	return &registryClient{repo: repo}, nil
}

type segmentRef struct {
	segment
	Tag    string
	Digest digest.Digest
}

type manifestRef struct {
	Tag       string
	Digest    digest.Digest
	Metadata  ocispec.Descriptor
	NARLayers map[string]ocispec.Descriptor
}

// The deadline covers body reads, which transport retries cannot restart.
func registryRequest[T any](ctx context.Context, name string, request func(context.Context) (T, error)) (T, error) {
	var zero T
	for attempt := 1; ; attempt++ {
		requestCtx, cancel := context.WithTimeout(ctx, registryTimeout)
		value, err := request(requestCtx)
		cancel()
		if err == nil {
			return value, nil
		}
		if ctx.Err() != nil {
			return zero, ctx.Err()
		}
		if !errors.Is(err, context.DeadlineExceeded) || attempt == registryTimeoutAttempts {
			return zero, err
		}
		log.Printf("%s timed out, retrying (%d/%d)", name, attempt+1, registryTimeoutAttempts)
	}
}

func (client *registryClient) repositoryTags(ctx context.Context) ([]string, error) {
	tags, err := registryRequest(ctx, "list cache tags", func(ctx context.Context) ([]string, error) {
		return registry.Tags(ctx, client.repo)
	})
	if errors.Is(err, errdef.ErrNotFound) || isNameUnknown(err) {
		return nil, nil
	}
	if err != nil {
		return nil, fmt.Errorf("list cache tags: %w", err)
	}
	return tags, nil
}

func segmentTags(tags []string, system string) []string {
	selected := make([]string, 0, len(tags))
	for _, tag := range tags {
		suffix, ok := strings.CutPrefix(tag, segmentPrefix)
		if !ok {
			continue
		}
		_, suffix, ok = strings.Cut(suffix, "-")
		if system != "" && (!ok || !strings.HasPrefix(suffix, system+"-")) {
			continue
		}
		selected = append(selected, tag)
	}
	return selected
}

func (client *registryClient) listTags(ctx context.Context, system string) ([]string, error) {
	tags, err := client.repositoryTags(ctx)
	if err != nil {
		return nil, err
	}
	return segmentTags(tags, system), nil
}

func (client *registryClient) listSegments(ctx context.Context, system string) ([]segmentRef, error) {
	tags, err := client.listTags(ctx, system)
	if err != nil {
		return nil, err
	}
	segments, err := client.fetchSegments(ctx, tags)
	if err != nil {
		return nil, err
	}
	slices.SortFunc(segments, compareSegments)
	return segments, nil
}

func (client *registryClient) listManifests(ctx context.Context, system string) ([]manifestRef, error) {
	tags, err := client.listTags(ctx, system)
	if err != nil {
		return nil, err
	}
	return loadTags(ctx, tags, client.getManifest)
}

func (client *registryClient) fetchSegments(ctx context.Context, tags []string) ([]segmentRef, error) {
	return loadTags(ctx, tags, client.getSegment)
}

func loadTags[T any](ctx context.Context, tags []string, fetch func(context.Context, string) (T, error)) ([]T, error) {
	items := make([]T, len(tags))
	missing := make([]bool, len(tags))
	group, groupCtx := errgroup.WithContext(ctx)
	group.SetLimit(segmentLoadConcurrency)
	for index, tag := range tags {
		group.Go(func() error {
			if err := groupCtx.Err(); err != nil {
				return err
			}
			item, err := fetch(groupCtx, tag)
			if errors.Is(err, errdef.ErrNotFound) {
				missing[index] = true
				log.Printf("segment %s disappeared while loading, skipping", tag)
				return nil
			}
			if err != nil {
				return fmt.Errorf("load %s: %w", tag, err)
			}
			items[index] = item
			return nil
		})
	}
	if err := group.Wait(); err != nil {
		return nil, err
	}
	loaded := items[:0]
	for index, item := range items {
		if !missing[index] {
			loaded = append(loaded, item)
		}
	}
	clear(items[len(loaded):])
	return loaded, nil
}

func isNameUnknown(err error) bool {
	var response *errcode.ErrorResponse
	if !errors.As(err, &response) {
		return false
	}
	for _, item := range response.Errors {
		if item.Code == errcode.ErrorCodeNameUnknown {
			return true
		}
	}
	return false
}

func (client *registryClient) fetchManifest(ctx context.Context, tag string) (ocispec.Descriptor, ocispec.Manifest, error) {
	descriptor, body, err := oras.FetchBytes(ctx, client.repo, tag, oras.FetchBytesOptions{MaxBytes: maxMetadataSize})
	if err != nil {
		return ocispec.Descriptor{}, ocispec.Manifest{}, err
	}
	var manifest ocispec.Manifest
	err = json.Unmarshal(body, &manifest)
	return descriptor, manifest, err
}

func (client *registryClient) fetchMetadata(ctx context.Context, descriptor ocispec.Descriptor) ([]byte, error) {
	if descriptor.Size < 0 || descriptor.Size > maxMetadataSize {
		return nil, fmt.Errorf("metadata size %d exceeds allowed range", descriptor.Size)
	}
	return content.FetchAll(ctx, client.repo, descriptor)
}

func (client *registryClient) getManifest(ctx context.Context, tag string) (manifestRef, error) {
	return registryRequest(ctx, "fetch manifest "+tag, func(ctx context.Context) (manifestRef, error) {
		descriptor, manifest, err := client.fetchManifest(ctx, tag)
		if err != nil {
			return manifestRef{}, err
		}
		if len(manifest.Layers) == 0 {
			return manifestRef{}, fmt.Errorf("segment has no metadata layer")
		}
		metadata := manifest.Layers[0]
		if metadata.MediaType != segmentMediaType {
			return manifestRef{}, fmt.Errorf("unexpected metadata media type %q", metadata.MediaType)
		}
		if metadata.Size < 0 {
			return manifestRef{}, fmt.Errorf("metadata layer has invalid size %d", metadata.Size)
		}
		narLayers := make(map[string]ocispec.Descriptor, len(manifest.Layers)-1)
		for _, layer := range manifest.Layers[1:] {
			if layer.MediaType != narMediaType {
				return manifestRef{}, fmt.Errorf("unexpected NAR media type %q", layer.MediaType)
			}
			if layer.Size < 0 {
				return manifestRef{}, fmt.Errorf("layer %s has invalid size %d", layer.Digest, layer.Size)
			}
			hash := layer.Annotations[storeHashAnnotation]
			if hash == "" {
				return manifestRef{}, fmt.Errorf("NAR layer %s is missing %s annotation", layer.Digest, storeHashAnnotation)
			}
			if _, exists := narLayers[hash]; exists {
				return manifestRef{}, fmt.Errorf("duplicate NAR layer for store hash %s", hash)
			}
			narLayers[hash] = layer
		}
		return manifestRef{Tag: tag, Digest: descriptor.Digest, Metadata: metadata, NARLayers: narLayers}, nil
	})
}

func (client *registryClient) getSegment(ctx context.Context, tag string) (segmentRef, error) {
	manifest, err := client.getManifest(ctx, tag)
	if err != nil {
		return segmentRef{}, err
	}
	return registryRequest(ctx, "fetch segment metadata "+tag, func(ctx context.Context) (segmentRef, error) {
		body, err := client.fetchMetadata(ctx, manifest.Metadata)
		if err != nil {
			return segmentRef{}, err
		}
		var item segment
		if err := json.Unmarshal(body, &item); err != nil {
			return segmentRef{}, fmt.Errorf("decode segment metadata: %w", err)
		}
		if item.Version != segmentVersion {
			return segmentRef{}, fmt.Errorf("unsupported segment version %d", item.Version)
		}
		if err := validateSegment(tag, item, manifest); err != nil {
			return segmentRef{}, err
		}
		return segmentRef{segment: item, Tag: tag, Digest: manifest.Digest}, nil
	})
}

func validateSegment(tag string, item segment, manifest manifestRef) error {
	if item.Snapshot == "" || item.System == "" || item.CreatedAt.IsZero() {
		return fmt.Errorf("segment metadata is missing snapshot, system, or createdAt")
	}
	if !strings.HasPrefix(tag, segmentTagPrefix(item.Snapshot, item.System)) {
		return fmt.Errorf("tag %q does not match metadata snapshot %q and system %q", tag, item.Snapshot, item.System)
	}
	if len(item.Entries) != len(manifest.NARLayers) {
		return fmt.Errorf("segment has %d entries but %d NAR layers", len(item.Entries), len(manifest.NARLayers))
	}
	for hash, entry := range item.Entries {
		actualHash, err := storeHash(entry.StorePath)
		if err != nil {
			return fmt.Errorf("entry %s has invalid store path: %w", hash, err)
		}
		if actualHash != hash {
			return fmt.Errorf("entry key %q does not match store path hash %q", hash, actualHash)
		}
		if path.Clean(entry.NARURL) != entry.NARURL || !strings.HasPrefix(entry.NARURL, "nar/") {
			return fmt.Errorf("entry %s has invalid NAR URL %q", hash, entry.NARURL)
		}
		narDigest, err := digest.Parse(entry.NARDigest)
		if err != nil || narDigest.Algorithm() != digest.SHA256 || entry.NARSize <= 0 {
			return fmt.Errorf("entry %s has invalid NAR digest or size", hash)
		}
		layer, ok := manifest.NARLayers[hash]
		if !ok || layer.MediaType != narMediaType || layer.Annotations[storeHashAnnotation] != hash ||
			layer.Digest != narDigest || layer.Size != entry.NARSize {
			return fmt.Errorf("entry %s does not match its manifest NAR layer", hash)
		}
		info, err := narinfo.Parse(strings.NewReader(entry.NARInfo))
		if err != nil {
			return fmt.Errorf("entry %s has invalid narinfo: %w", hash, err)
		}
		if err := info.Check(); err != nil {
			return fmt.Errorf("entry %s has invalid narinfo: %w", hash, err)
		}
		if info.StorePath != entry.StorePath || info.URL != entry.NARURL ||
			info.FileHash == nil || info.FileHash.Algo().String() != digest.SHA256.String() ||
			digest.NewDigestFromEncoded(digest.SHA256, digest.SHA256.Encode(info.FileHash.Digest())).String() != entry.NARDigest ||
			int64(info.FileSize) != entry.NARSize {
			return fmt.Errorf("entry %s metadata does not match narinfo", hash)
		}
	}
	return nil
}

func compareSegments(a, b segmentRef) int {
	if order := a.CreatedAt.Compare(b.CreatedAt); order != 0 {
		return order
	}
	return cmp.Compare(a.Tag, b.Tag)
}

func (client *registryClient) blobReader(ctx context.Context, digest string) (io.ReadCloser, error) {
	_, reader, err := client.repo.Blobs().FetchReference(ctx, digest)
	return reader, err
}

func (client *registryClient) pushManifest(ctx context.Context, tag string, layers []ocispec.Descriptor) error {
	body, err := json.Marshal(ocispec.Manifest{
		Versioned: specs.Versioned{SchemaVersion: 2},
		MediaType: ocispec.MediaTypeImageManifest,
		Config:    layers[0],
		Layers:    layers,
	})
	if err != nil {
		return err
	}
	descriptor := content.NewDescriptorFromBytes(ocispec.MediaTypeImageManifest, body)
	return client.repo.PushReference(ctx, descriptor, bytes.NewReader(body), tag)
}

func segmentTagPrefix(snapshotID, system string) string {
	short := strings.TrimPrefix(snapshotID, "sha256:")
	return fmt.Sprintf("%s%s-%s-", segmentPrefix, short[:min(len(short), 16)], system)
}
