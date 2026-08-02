package main

import (
	"bytes"
	"context"
	"crypto/rand"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"slices"
	"strings"
	"time"

	"github.com/opencontainers/go-digest"
	"github.com/opencontainers/image-spec/specs-go"
	ocispec "github.com/opencontainers/image-spec/specs-go/v1"
	"oras.land/oras-go/v2/content"
	"oras.land/oras-go/v2/errdef"
	"oras.land/oras-go/v2/registry"
)

const gcPrefix = "gc-v1-"
const gcMediaType = "application/vnd.curoky.nixcache.gc.v1+json"
const gcGrace = 24 * time.Hour

type gcCandidate struct {
	Digest digest.Digest `json:"digest"`
	Since  time.Time     `json:"since"`
}

type gcState struct {
	Version    int                    `json:"version"`
	CreatedAt  time.Time              `json:"createdAt"`
	Candidates map[string]gcCandidate `json:"candidates"`
}

func (client *registryClient) loadGC(ctx context.Context) (gcState, []string, error) {
	state := gcState{Version: 1, Candidates: make(map[string]gcCandidate)}
	tags, err := registryRequest(ctx, "list GC records", func(ctx context.Context) ([]string, error) { return registry.Tags(ctx, client.repo) })
	if errors.Is(err, errdef.ErrNotFound) || isNameUnknown(err) {
		return state, nil, nil
	}
	if err != nil {
		return state, nil, err
	}
	tags = slices.DeleteFunc(tags, func(tag string) bool { return !strings.HasPrefix(tag, gcPrefix) })
	slices.Sort(tags)
	if len(tags) == 0 {
		return state, nil, nil
	}
	_, err = registryRequest(ctx, "read GC record", func(ctx context.Context) (bool, error) {
		descriptor, reader, err := client.repo.FetchReference(ctx, tags[len(tags)-1])
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
		if manifest.SchemaVersion != 2 || len(manifest.Layers) != 1 || manifest.Layers[0].MediaType != gcMediaType {
			return false, fmt.Errorf("invalid GC manifest")
		}
		blob, err := client.repo.Fetch(ctx, manifest.Layers[0])
		if err != nil {
			return false, err
		}
		defer blob.Close()
		body, err = readMetadata(blob, manifest.Layers[0])
		if err != nil {
			return false, err
		}
		state = gcState{}
		decoder := json.NewDecoder(bytes.NewReader(body))
		decoder.DisallowUnknownFields()
		if err := decoder.Decode(&state); err != nil {
			return false, err
		}
		var extra any
		if err := decoder.Decode(&extra); err != io.EOF {
			return false, fmt.Errorf("GC record must contain exactly one JSON document")
		}
		if state.Version != 1 || state.CreatedAt.IsZero() || state.Candidates == nil {
			return false, fmt.Errorf("invalid GC record")
		}
		if !strings.HasPrefix(tags[len(tags)-1], gcPrefix+state.CreatedAt.UTC().Format("20060102T150405.000000000Z")+"-") {
			return false, fmt.Errorf("GC record timestamp does not match tag")
		}
		for tag, item := range state.Candidates {
			if !strings.HasPrefix(tag, segmentPrefix) || item.Digest.Validate() != nil || item.Since.IsZero() || item.Since.After(state.CreatedAt) {
				return false, fmt.Errorf("invalid GC candidate %s", tag)
			}
		}
		return true, nil
	})
	return state, tags, err
}

func gcPlan(candidates []segmentRef, previous gcState, now time.Time) (gcState, []segmentRef) {
	next := gcState{Version: 1, CreatedAt: now, Candidates: make(map[string]gcCandidate)}
	var eligible []segmentRef
	for _, ref := range candidates {
		item, ok := previous.Candidates[ref.Tag]
		if !ok || item.Digest != ref.Digest || item.Since.After(now) {
			item = gcCandidate{Digest: ref.Digest, Since: now}
		}
		next.Candidates[ref.Tag] = item
		if now.Sub(item.Since) >= gcGrace {
			eligible = append(eligible, ref)
		}
	}
	return next, eligible
}

func (client *registryClient) saveGC(ctx context.Context, state gcState) error {
	body, err := json.Marshal(state)
	if err != nil {
		return err
	}
	if len(body) > maxMetadataSize {
		return fmt.Errorf("GC record exceeds metadata limit")
	}
	descriptor := content.NewDescriptorFromBytes(gcMediaType, body)
	if err := client.repo.Blobs().Push(ctx, descriptor, bytes.NewReader(body)); err != nil && !errors.Is(err, errdef.ErrAlreadyExists) {
		return err
	}
	manifest, err := json.Marshal(ocispec.Manifest{
		Versioned: specs.Versioned{SchemaVersion: 2}, MediaType: ocispec.MediaTypeImageManifest,
		Config: descriptor, Layers: []ocispec.Descriptor{descriptor},
	})
	if err != nil {
		return err
	}
	tag := gcPrefix + state.CreatedAt.UTC().Format("20060102T150405.000000000Z") + "-" + rand.Text()
	return client.repo.PushReference(ctx, content.NewDescriptorFromBytes(ocispec.MediaTypeImageManifest, manifest), bytes.NewReader(manifest), tag)
}
