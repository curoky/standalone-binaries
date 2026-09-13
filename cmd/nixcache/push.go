package main

import (
	"bytes"
	"context"
	"crypto/rand"
	"encoding/json"
	"errors"
	"fmt"
	"log"
	"maps"
	"net/url"
	"os"
	"os/exec"
	"path"
	"path/filepath"
	"slices"
	"strings"
	"time"

	"github.com/nix-community/go-nix/pkg/narinfo"
	"github.com/opencontainers/go-digest"
	ocispec "github.com/opencontainers/image-spec/specs-go/v1"
	"golang.org/x/sync/errgroup"
	"oras.land/oras-go/v2/content"
	"oras.land/oras-go/v2/errdef"
)

func pushPaths(ctx context.Context, client *registryClient, repoRoot, packageKey string, storePaths []string) error {
	state, err := loadSnapshot(repoRoot)
	if err != nil {
		return err
	}
	log.Printf("pushing %d store path(s) for %s package %s snapshot %s", len(storePaths), state.System, packageKey, state.ID)

	cacheDir, err := os.MkdirTemp("", "nixcache-*")
	if err != nil {
		return err
	}
	defer func() { _ = os.RemoveAll(cacheDir) }()

	query := url.Values{
		"compression":          {"zstd"},
		"parallel-compression": {"true"},
	}
	if key := os.Getenv("NIX_SIGNING_KEY_FILE"); key != "" {
		query.Set("secret-key", key)
	}
	destination := url.URL{
		Scheme:   "file",
		Path:     cacheDir,
		RawQuery: query.Encode(),
	}
	args := append([]string{"copy", "--to", destination.String()}, storePaths...)
	command := exec.CommandContext(ctx, "nix", args...)
	command.Stdout = os.Stdout
	command.Stderr = os.Stderr
	if err := command.Run(); err != nil {
		return fmt.Errorf("nix copy: %w", err)
	}
	entries, err := readCache(cacheDir)
	if err != nil {
		return err
	}
	log.Printf("collected %d cache entr(ies) from nix copy", len(entries))
	return client.pushSegment(ctx, state, packageKey, entries)
}

func readCache(cacheDir string) (map[string]cacheEntry, error) {
	files, err := filepath.Glob(filepath.Join(cacheDir, "*"+narInfoSuffix))
	if err != nil {
		return nil, err
	}
	entries := make(map[string]cacheEntry, len(files))
	for _, file := range files {
		body, err := os.ReadFile(file)
		if err != nil {
			return nil, err
		}
		info, err := narinfo.Parse(bytes.NewReader(body))
		if err != nil {
			return nil, fmt.Errorf("parse %s: %w", filepath.Base(file), err)
		}
		if err := info.Check(); err != nil {
			return nil, fmt.Errorf("check %s: %w", filepath.Base(file), err)
		}
		if path.Clean(info.URL) != info.URL || !strings.HasPrefix(info.URL, "nar/") {
			return nil, fmt.Errorf("invalid NAR URL %q", info.URL)
		}
		narPath := filepath.Join(cacheDir, filepath.FromSlash(info.URL))
		if info.FileHash == nil || info.FileHash.Algo().String() != digest.SHA256.String() || info.FileSize == 0 {
			return nil, fmt.Errorf("invalid NAR file metadata for %q", info.URL)
		}
		hash, err := storeHash(info.StorePath)
		if err != nil {
			return nil, err
		}
		entries[hash] = cacheEntry{
			StorePath: info.StorePath,
			NARURL:    info.URL,
			NARDigest: digest.NewDigestFromEncoded(
				digest.SHA256,
				digest.SHA256.Encode(info.FileHash.Digest()),
			).String(),
			NARSize: int64(info.FileSize),
			NARInfo: string(body),
			NARPath: narPath,
		}
	}
	if len(entries) == 0 {
		return nil, fmt.Errorf("nix copy produced no narinfo files")
	}
	return entries, nil
}

const narUploadConcurrency = 8

func (client *registryClient) pushSegment(ctx context.Context, state snapshot, packageKey string, entries map[string]cacheEntry) error {
	runID := os.Getenv("GITHUB_RUN_ID")
	if runID == "" {
		runID = fmt.Sprintf("%d", time.Now().UnixNano())
	}
	item := segment{
		Version: segmentVersion, Snapshot: state.ID, RepositoryCommit: state.RepositoryCommit,
		System: state.System, PackageKey: packageKey, RunID: runID, CreatedAt: time.Now().UTC(),
		Channels: state.Channels, Entries: entries,
	}
	metadata, err := json.Marshal(item)
	if err != nil {
		return err
	}
	metadataDescriptor := content.NewDescriptorFromBytes(segmentMediaType, metadata)
	if err := client.repo.Blobs().Push(ctx, metadataDescriptor, bytes.NewReader(metadata)); err != nil && !errors.Is(err, errdef.ErrAlreadyExists) {
		return err
	}

	hashes := slices.Sorted(maps.Keys(entries))
	layers := make([]ocispec.Descriptor, len(hashes)+1)
	layers[0] = metadataDescriptor
	uploaded := make([]bool, len(hashes))
	group, groupCtx := errgroup.WithContext(ctx)
	group.SetLimit(narUploadConcurrency)
	for index, hash := range hashes {
		entry := entries[hash]
		descriptor := ocispec.Descriptor{
			MediaType: narMediaType, Digest: digest.Digest(entry.NARDigest), Size: entry.NARSize,
			Annotations: map[string]string{storeHashAnnotation: hash},
		}
		layers[index+1] = descriptor
		group.Go(func() error {
			if err := groupCtx.Err(); err != nil {
				return err
			}
			pushed, err := client.pushFile(groupCtx, descriptor, entry.NARPath)
			if err != nil {
				return fmt.Errorf("push NAR for %s: %w", hash, err)
			}
			uploaded[index] = pushed
			return nil
		})
	}
	if err := group.Wait(); err != nil {
		return err
	}
	var uploadedCount int
	for _, pushed := range uploaded {
		if pushed {
			uploadedCount++
		}
	}
	log.Printf("pushed %d NAR blob(s), skipped %d already present", uploadedCount, len(uploaded)-uploadedCount)
	tag := fmt.Sprintf("%s%s-%s", segmentTagPrefix(state.ID, state.System), runID, rand.Text())
	if err := client.pushManifest(ctx, tag, layers); err != nil {
		return fmt.Errorf("publish segment %s: %w", tag, err)
	}
	log.Printf("published segment %s for package %s (%d entries)", tag, packageKey, len(entries))
	return nil
}

func (client *registryClient) pushFile(ctx context.Context, descriptor ocispec.Descriptor, path string) (bool, error) {
	exists, err := client.repo.Blobs().Exists(ctx, descriptor)
	if err != nil || exists {
		return false, err
	}
	file, err := os.Open(path)
	if err != nil {
		return false, err
	}
	defer func() { _ = file.Close() }() // Read-only file; upload errors are reported below.
	if err := client.repo.Blobs().Push(ctx, descriptor, file); err != nil {
		if errors.Is(err, errdef.ErrAlreadyExists) {
			return false, nil
		}
		return false, err
	}
	return true, nil
}
