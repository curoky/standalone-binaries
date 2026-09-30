package main

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"path"
	"path/filepath"
	"strings"

	"github.com/opencontainers/go-digest"
)

const frozenIndexVersion = 1

type frozenIndex struct {
	Version int                   `json:"version"`
	System  string                `json:"system"`
	Entries map[string]cacheEntry `json:"entries"`
	NARs    map[string]narBlob    `json:"nars"`
}

func createFrozenIndex(ctx context.Context, client *registryClient, system, filePath string) error {
	index := newCacheIndex(client, system)
	if _, err := index.refresh(ctx); err != nil {
		return fmt.Errorf("load cache segments: %w", err)
	}
	current := index.current.Load()
	contents, err := json.MarshalIndent(frozenIndex{
		Version: frozenIndexVersion,
		System:  system,
		Entries: current.entries,
		NARs:    current.nars,
	}, "", "  ")
	if err != nil {
		return fmt.Errorf("encode frozen cache index: %w", err)
	}
	contents = append(contents, '\n')
	if len(contents) > maxMetadataSize {
		return fmt.Errorf("frozen cache index size %d exceeds limit %d", len(contents), maxMetadataSize)
	}
	if err := writeFileAtomic(filePath, contents); err != nil {
		return fmt.Errorf("write frozen cache index: %w", err)
	}
	return nil
}

func loadFrozenIndex(filePath, system string) (*indexSnapshot, error) {
	file, err := os.Open(filePath)
	if err != nil {
		return nil, err
	}
	defer func() { _ = file.Close() }()
	if info, err := file.Stat(); err != nil {
		return nil, err
	} else if info.Size() > maxMetadataSize {
		return nil, fmt.Errorf("frozen cache index size %d exceeds limit %d", info.Size(), maxMetadataSize)
	}
	contents, err := io.ReadAll(io.LimitReader(file, maxMetadataSize+1))
	if err != nil {
		return nil, err
	}
	if len(contents) > maxMetadataSize {
		return nil, fmt.Errorf("frozen cache index exceeds size limit %d", maxMetadataSize)
	}

	var frozen frozenIndex
	decoder := json.NewDecoder(bytes.NewReader(contents))
	decoder.DisallowUnknownFields()
	if err := decoder.Decode(&frozen); err != nil {
		return nil, fmt.Errorf("decode frozen cache index: %w", err)
	}
	if err := decoder.Decode(&struct{}{}); err != io.EOF {
		if err == nil {
			return nil, fmt.Errorf("decode frozen cache index: multiple JSON values")
		}
		return nil, fmt.Errorf("decode frozen cache index: %w", err)
	}
	if frozen.Version != frozenIndexVersion {
		return nil, fmt.Errorf("unsupported frozen cache index version %d", frozen.Version)
	}
	if frozen.System != system {
		return nil, fmt.Errorf("frozen cache index system %q does not match current system %q", frozen.System, system)
	}
	if frozen.Entries == nil || frozen.NARs == nil {
		return nil, fmt.Errorf("frozen cache index entries and nars must be JSON objects")
	}
	for narURL, blob := range frozen.NARs {
		if err := validateNARBlob(narURL, blob); err != nil {
			return nil, err
		}
	}
	for hash, entry := range frozen.Entries {
		if err := validateCacheEntry(hash, entry); err != nil {
			return nil, err
		}
		blob, ok := frozen.NARs[entry.NARURL]
		if !ok {
			return nil, fmt.Errorf("entry %s has no NAR descriptor for URL %q", hash, entry.NARURL)
		}
		if blob.Digest != entry.NARDigest || blob.Size != entry.NARSize {
			return nil, fmt.Errorf("entry %s does not match NAR descriptor for URL %q", hash, entry.NARURL)
		}
	}
	return &indexSnapshot{entries: frozen.Entries, nars: frozen.NARs}, nil
}

func validateNARBlob(narURL string, blob narBlob) error {
	if path.Clean(narURL) != narURL || !strings.HasPrefix(narURL, "nar/") {
		return fmt.Errorf("invalid NAR descriptor URL %q", narURL)
	}
	narDigest, err := digest.Parse(blob.Digest)
	if err != nil || narDigest.Algorithm() != digest.SHA256 || blob.Size <= 0 {
		return fmt.Errorf("NAR descriptor %q has invalid digest or size", narURL)
	}
	return nil
}

func writeFileAtomic(filePath string, contents []byte) (err error) {
	temporary, err := os.CreateTemp(filepath.Dir(filePath), "."+filepath.Base(filePath)+"-*")
	if err != nil {
		return err
	}
	temporaryPath := temporary.Name()
	defer func() {
		_ = temporary.Close()
		_ = os.Remove(temporaryPath)
	}()
	if err := temporary.Chmod(0o644); err != nil {
		return err
	}
	if _, err := temporary.Write(contents); err != nil {
		return err
	}
	if err := temporary.Sync(); err != nil {
		return err
	}
	if err := temporary.Close(); err != nil {
		return err
	}
	return os.Rename(temporaryPath, filePath)
}
