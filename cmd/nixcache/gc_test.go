package main

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync/atomic"
	"testing"
	"time"

	"github.com/google/go-containerregistry/pkg/registry"
	"github.com/opencontainers/go-digest"
	"github.com/opencontainers/image-spec/specs-go"
	ocispec "github.com/opencontainers/image-spec/specs-go/v1"
	"oras.land/oras-go/v2/content"
)

func TestGCGraceAndReachabilityReset(t *testing.T) {
	now := time.Now().UTC()
	candidate := ref("s1", "x86_64-linux", "pkg", "v1-candidate", 1)
	candidate.Digest = digest.FromString("manifest")
	state, eligible := gcPlan([]segmentRef{candidate}, gcState{}, now)
	if len(eligible) != 0 || !state.Candidates[candidate.Tag].Since.Equal(now) {
		t.Fatal("new candidate eligible immediately")
	}
	_, eligible = gcPlan([]segmentRef{candidate}, state, now.Add(gcGrace-time.Nanosecond))
	if len(eligible) != 0 {
		t.Fatal("candidate deleted before grace period")
	}
	_, eligible = gcPlan([]segmentRef{candidate}, state, now.Add(gcGrace))
	if len(eligible) != 1 {
		t.Fatal("candidate not eligible at boundary")
	}
	reset, _ := gcPlan(nil, state, now.Add(gcGrace))
	reset, eligible = gcPlan([]segmentRef{candidate}, reset, now.Add(2*gcGrace))
	if len(eligible) != 0 || !reset.Candidates[candidate.Tag].Since.Equal(now.Add(2*gcGrace)) {
		t.Fatal("reachability did not reset grace")
	}
	candidate.Digest = digest.FromString("changed")
	changed, eligible := gcPlan([]segmentRef{candidate}, state, now.Add(2*gcGrace))
	if len(eligible) != 0 || changed.Candidates[candidate.Tag].Digest != candidate.Digest {
		t.Fatal("digest change did not reset grace")
	}
}

func TestGCRecordRoundTripAndIsolation(t *testing.T) {
	client := testRegistryClient(t)
	ctx := context.Background()
	state, tags, err := client.loadGC(ctx)
	if err != nil || len(tags) != 0 {
		t.Fatalf("empty record: %v %v", tags, err)
	}
	now := time.Now().UTC()
	state.CreatedAt = now
	state.Candidates["v1-test"] = gcCandidate{Digest: digest.FromString("manifest"), Since: now}
	if err := client.saveGC(ctx, state); err != nil {
		t.Fatal(err)
	}
	loaded, tags, err := client.loadGC(ctx)
	if err != nil || len(tags) != 1 || !loaded.Candidates["v1-test"].Since.Equal(now) {
		t.Fatalf("record: %+v %v", loaded, err)
	}
	if segments, err := client.listTags(ctx, ""); err != nil || len(segments) != 0 {
		t.Fatalf("GC record exposed as segment: %v %v", segments, err)
	}
	state.CreatedAt = now.Add(time.Second)
	state.Candidates = map[string]gcCandidate{}
	if err := client.saveGC(ctx, state); err != nil {
		t.Fatal(err)
	}
	loaded, tags, err = client.loadGC(ctx)
	if err != nil || len(tags) != 2 || len(loaded.Candidates) != 0 {
		t.Fatalf("latest reset not selected: %+v %v", loaded, err)
	}
}

func TestGCRejectsInvalidRecords(t *testing.T) {
	now := time.Now().UTC()
	valid, err := json.Marshal(gcState{Version: 1, CreatedAt: now, Candidates: map[string]gcCandidate{}})
	if err != nil {
		t.Fatal(err)
	}
	for name, body := range map[string]string{
		"missing version":    strings.Replace(string(valid), `"version":1,`, "", 1),
		"missing candidates": strings.Replace(string(valid), `,"candidates":{}`, "", 1),
		"null candidates":    strings.Replace(string(valid), `"candidates":{}`, `"candidates":null`, 1),
		"trailing document":  string(valid) + " {}",
		"timestamp mismatch": strings.Replace(string(valid), now.Format(time.RFC3339Nano), now.Add(time.Second).Format(time.RFC3339Nano), 1),
		"unknown field":      strings.Replace(string(valid), `"version":`, `"extra":true,"version":`, 1),
	} {
		t.Run(name, func(t *testing.T) {
			client := testRegistryClient(t)
			ctx := context.Background()
			descriptor := content.NewDescriptorFromBytes(gcMediaType, []byte(body))
			if err := client.repo.Blobs().Push(ctx, descriptor, strings.NewReader(body)); err != nil {
				t.Fatal(err)
			}
			manifest, err := json.Marshal(ocispec.Manifest{Versioned: specs.Versioned{SchemaVersion: 2}, MediaType: ocispec.MediaTypeImageManifest, Config: descriptor, Layers: []ocispec.Descriptor{descriptor}})
			if err != nil {
				t.Fatal(err)
			}
			tag := gcPrefix + now.Format("20060102T150405.000000000Z") + "-test"
			if err := client.repo.PushReference(ctx, content.NewDescriptorFromBytes(ocispec.MediaTypeImageManifest, manifest), bytes.NewReader(manifest), tag); err != nil {
				t.Fatal(err)
			}
			if _, _, err := client.loadGC(ctx); err == nil {
				t.Fatal("accepted invalid GC record")
			}
		})
	}
}

func TestGCWriteFailureNeverDeletes(t *testing.T) {
	var rejectWrites atomic.Bool
	handler := registry.New()
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if rejectWrites.Load() && r.Method != http.MethodGet && r.Method != http.MethodHead {
			w.WriteHeader(http.StatusForbidden)
			return
		}
		handler.ServeHTTP(w, r)
	}))
	defer server.Close()
	client, err := newRegistryClient(server.Listener.Addr().String()+"/cache", true)
	if err != nil {
		t.Fatal(err)
	}
	ctx := context.Background()
	pushTestSegment(t, client, "sha256:"+strings.Repeat("1", 64), "x86_64-linux", "pkg", "1", "nar")
	segments, err := client.listSegments(ctx, "")
	if err != nil {
		t.Fatal(err)
	}
	state, _ := gcPlan(segments, gcState{}, time.Now().UTC())
	mapping := map[string]int64{segments[0].Tag: 1}
	rejectWrites.Store(true)
	deleter := &fakeVersionDeleter{}
	if _, err := executeGC(ctx, client, deleter, state, segments, nil, mapping); err == nil {
		t.Fatal("expected GC persistence failure")
	}
	if len(deleter.deleted) != 0 {
		t.Fatal("deleted versions after persistence failure")
	}
	if _, tags, err := client.loadGC(ctx); err != nil || len(tags) != 0 {
		t.Fatalf("failed write left GC records: %v %v", tags, err)
	}
}

func TestPruneRejectsClockRollback(t *testing.T) {
	client := testRegistryClient(t)
	pushTestSegment(t, client, "sha256:"+strings.Repeat("1", 64), "x86_64-linux", "pkg", "1", "nar")
	ctx := context.Background()
	state := gcState{Version: 1, CreatedAt: time.Now().Add(time.Hour), Candidates: map[string]gcCandidate{}}
	if err := client.saveGC(ctx, state); err != nil {
		t.Fatal(err)
	}
	if err := pruneCache(ctx, client, testRoots(), 1, 2, 2, true); err == nil || !strings.Contains(err.Error(), "clock") {
		t.Fatalf("clock rollback: %v", err)
	}
}

func TestExecuteGCPreflightsAndPersistsBeforeDeleting(t *testing.T) {
	ctx := context.Background()
	client := testRegistryClient(t)
	pushTestSegment(t, client, "sha256:"+strings.Repeat("1", 64), "x86_64-linux", "pkg", "1", "nar")
	segments, err := client.listSegments(ctx, "")
	if err != nil {
		t.Fatal(err)
	}
	now := time.Now().UTC()
	state, _ := gcPlan(segments, gcState{}, now)
	deleter := &fakeVersionDeleter{}
	if _, err := executeGC(ctx, client, deleter, state, segments, nil, nil); err == nil || len(deleter.deleted) != 0 {
		t.Fatal("missing mapping allowed deletion")
	}
	_, tags, err := client.loadGC(ctx)
	if err != nil || len(tags) != 0 {
		t.Fatal("preflight failure wrote a GC record")
	}
	mapping := map[string]int64{segments[0].Tag: 1}
	changed := append([]segmentRef(nil), segments...)
	changed[0].Digest = digest.FromString("wrong")
	if _, err := executeGC(ctx, client, deleter, state, changed, nil, mapping); err == nil || len(deleter.deleted) != 0 {
		t.Fatal("changed tag allowed deletion")
	}
	deleter.err = errors.New("delete failure")
	if _, err := executeGC(ctx, client, deleter, state, segments, nil, mapping); err == nil {
		t.Fatal("expected delete failure")
	}
	loaded, tags, err := client.loadGC(ctx)
	if err != nil || len(tags) != 1 || len(loaded.Candidates) != 1 {
		t.Fatal("candidate state was not persisted before deletion")
	}
	deleter.err = nil
	mapping[tags[0]] = 2
	state.CreatedAt = now.Add(time.Second)
	if count, err := executeGC(ctx, client, deleter, state, segments, tags, mapping); err != nil || count != 1 {
		t.Fatalf("retry: %d %v", count, err)
	}
	if len(deleter.deleted) != 2 || deleter.deleted[0] != 2 || deleter.deleted[1] != 1 {
		t.Fatalf("cleanup order: %v", deleter.deleted)
	}
}
