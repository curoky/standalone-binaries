package main

import (
	"context"
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/google/go-containerregistry/pkg/registry"
)

func TestServeCache(t *testing.T) {
	client := testRegistryClient(t)

	hash := "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
	state := snapshot{
		ID:       "sha256:0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
		System:   "x86_64-linux",
		Channels: map[string]string{"nixpkgs-unstable": "revision"},
	}
	entry := testCacheEntry(t, hash, "root", []byte("compressed nar"))
	if err := client.pushSegment(context.Background(), state, "root", map[string]cacheEntry{hash: entry}); err != nil {
		t.Fatal(err)
	}
	index := newCacheIndex(client, "x86_64-linux")
	if _, err := index.refresh(context.Background()); err != nil {
		t.Fatal(err)
	}
	index.ready.Store(true)
	server := httptest.NewServer(http.HandlerFunc(index.serveHTTP))
	t.Cleanup(server.Close)

	assertResponse := func(method, path, contentType, body string) {
		t.Helper()
		request, err := http.NewRequest(method, server.URL+path, nil)
		if err != nil {
			t.Fatal(err)
		}
		response, err := http.DefaultClient.Do(request)
		if err != nil {
			t.Fatal(err)
		}
		defer func() { _ = response.Body.Close() }()
		if response.StatusCode != http.StatusOK {
			t.Fatalf("%s %s status=%d", method, path, response.StatusCode)
		}
		if got := response.Header.Get("Content-Type"); got != contentType {
			t.Fatalf("%s content type=%q want %q", path, got, contentType)
		}
		got, err := io.ReadAll(response.Body)
		if err != nil {
			t.Fatal(err)
		}
		if string(got) != body {
			t.Fatalf("%s body=%q want %q", path, got, body)
		}
	}

	assertResponse(http.MethodGet, "/nix-cache-info", "text/x-nix-cache-info", nixCacheInfo)
	assertResponse(http.MethodGet, "/"+hash+".narinfo", "text/x-nix-narinfo", entry.NARInfo)
	assertResponse(http.MethodGet, "/"+entry.NARURL, "application/x-nix-nar", "compressed nar")
	assertResponse(http.MethodHead, "/"+entry.NARURL, "application/x-nix-nar", "")

	response, err := http.Get(server.URL + "/missing.narinfo")
	if err != nil {
		t.Fatal(err)
	}
	defer func() { _ = response.Body.Close() }()
	if response.StatusCode != http.StatusNotFound {
		t.Fatalf("missing status=%d", response.StatusCode)
	}
}

type refreshRegistry struct {
	client       *registryClient
	mu           sync.Mutex
	tags         []string
	requests     map[string]int
	failPath     string
	missingTag   string
	publishedTag string
}

func newRefreshRegistry(t *testing.T) *refreshRegistry {
	t.Helper()
	fixture := &refreshRegistry{requests: make(map[string]int)}
	backend := registry.New()
	server := httptest.NewServer(http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		fixture.mu.Lock()
		defer fixture.mu.Unlock()
		if request.Method == http.MethodGet {
			fixture.requests[request.URL.Path]++
			if request.URL.Path == fixture.failPath {
				http.Error(writer, "unavailable", http.StatusForbidden)
				return
			}
			if fixture.missingTag != "" && request.URL.Path == "/v2/cache/manifests/"+fixture.missingTag {
				http.NotFound(writer, request)
				return
			}
			if request.URL.Path == "/v2/cache/tags/list" {
				writer.Header().Set("Content-Type", "application/json")
				_ = json.NewEncoder(writer).Encode(map[string]any{"name": "cache", "tags": fixture.tags})
				return
			}
		}
		if request.Method == http.MethodPut && strings.HasPrefix(request.URL.Path, "/v2/cache/manifests/v1-") {
			fixture.publishedTag = strings.TrimPrefix(request.URL.Path, "/v2/cache/manifests/")
		}
		backend.ServeHTTP(writer, request)
	}))
	t.Cleanup(server.Close)
	client, err := newRegistryClient(server.Listener.Addr().String()+"/cache", true)
	if err != nil {
		t.Fatal(err)
	}
	fixture.client = client
	return fixture
}

func (fixture *refreshRegistry) publish(t *testing.T, state snapshot, entry cacheEntry) string {
	t.Helper()
	hash, err := storeHash(entry.StorePath)
	if err != nil {
		t.Fatal(err)
	}
	if err := fixture.client.pushSegment(context.Background(), state, "root", map[string]cacheEntry{hash: entry}); err != nil {
		t.Fatal(err)
	}
	fixture.mu.Lock()
	defer fixture.mu.Unlock()
	if fixture.publishedTag == "" {
		t.Fatal("segment tag was not published")
	}
	return fixture.publishedTag
}

func (fixture *refreshRegistry) list(tags ...string) {
	fixture.mu.Lock()
	defer fixture.mu.Unlock()
	fixture.tags = tags
	fixture.requests = make(map[string]int)
}

func (fixture *refreshRegistry) assertReads(t *testing.T, manifests, blobs int) {
	t.Helper()
	fixture.mu.Lock()
	defer fixture.mu.Unlock()
	var gotManifests, gotBlobs int
	for path, count := range fixture.requests {
		switch {
		case strings.HasPrefix(path, "/v2/cache/manifests/"):
			gotManifests += count
		case strings.HasPrefix(path, "/v2/cache/blobs/"):
			gotBlobs += count
		}
	}
	if fixture.requests["/v2/cache/tags/list"] != 1 || gotManifests != manifests || gotBlobs != blobs {
		t.Fatalf("requests=%v; want one listing, %d manifests, %d blobs", fixture.requests, manifests, blobs)
	}
}

func TestCacheRefreshIncrementalAcrossSnapshots(t *testing.T) {
	fixture := newRefreshRegistry(t)
	state := snapshot{
		ID:     "sha256:" + strings.Repeat("1", 64),
		System: "x86_64-linux",
	}
	old := testCacheEntry(t, strings.Repeat("a", 32), "root", []byte("old nar"))
	oldTag := fixture.publish(t, state, old)
	state.ID = "sha256:" + strings.Repeat("2", 64)
	newEntry := testCacheEntry(t, strings.Repeat("b", 32), "root", []byte("new nar"))
	newTag := fixture.publish(t, state, newEntry)
	state.System = "aarch64-linux"
	foreignTag := fixture.publish(t, state, old)
	state.System = "x86_64-linux-extra"
	prefixTag := fixture.publish(t, state, old)

	index := newCacheIndex(fixture.client, "x86_64-linux")
	server := httptest.NewServer(http.HandlerFunc(index.serveHTTP))
	t.Cleanup(server.Close)
	fixture.list(oldTag, foreignTag)
	if count, err := index.refresh(context.Background()); err != nil || count != 1 {
		t.Fatalf("initial refresh: count=%d err=%v", count, err)
	}
	fixture.assertReads(t, 1, 1)
	fixture.mu.Lock()
	if fixture.requests["/v2/cache/blobs/"+old.NARDigest] != 0 {
		t.Error("refresh downloaded NAR payload")
	}
	fixture.mu.Unlock()

	fixture.list(oldTag, foreignTag)
	if _, err := index.refresh(context.Background()); err != nil {
		t.Fatal(err)
	}
	fixture.assertReads(t, 0, 0)

	fixture.list(oldTag, newTag, foreignTag)
	if count, err := index.refresh(context.Background()); err != nil || count != 2 {
		t.Fatalf("incremental refresh: count=%d err=%v", count, err)
	}
	fixture.assertReads(t, 1, 1)
	for _, entry := range []cacheEntry{old, newEntry} {
		if hit, err := probeStorePath(context.Background(), http.DefaultClient, server.URL, entry.StorePath); err != nil || !hit {
			t.Fatalf("probe %s: hit=%t err=%v", entry.StorePath, hit, err)
		}
	}
	missing := "/nix/store/" + strings.Repeat("c", 32) + "-root"
	if hit, err := probeStorePath(context.Background(), http.DefaultClient, server.URL, missing); err != nil || hit {
		t.Fatalf("probe different store path: hit=%t err=%v", hit, err)
	}

	fixture.list(newTag, foreignTag)
	if count, err := index.refresh(context.Background()); err != nil || count != 1 {
		t.Fatalf("deletion refresh: count=%d err=%v", count, err)
	}
	fixture.assertReads(t, 0, 0)
	if _, ok := index.nars[old.NARURL]; ok {
		t.Fatal("deleted segment NAR is still indexed")
	}
	if hit, err := probeStorePath(context.Background(), http.DefaultClient, server.URL, old.StorePath); err != nil || hit {
		t.Fatalf("probe deleted path: hit=%t err=%v", hit, err)
	}

	fixture.list(newTag, prefixTag)
	if _, err := index.refresh(context.Background()); err == nil {
		t.Fatal("expected mismatched platform metadata to fail")
	}
	if len(index.segments) != 1 || len(index.entries) != 1 {
		t.Fatal("platform mismatch changed the index")
	}

	fixture.list()
	if count, err := index.refresh(context.Background()); err != nil || count != 0 {
		t.Fatalf("empty refresh: count=%d err=%v", count, err)
	}
	fixture.assertReads(t, 0, 0)
	if len(index.segments) != 0 || len(index.nars) != 0 {
		t.Fatal("deleted segments remain cached")
	}
}

func TestCacheRefreshFailurePreservesState(t *testing.T) {
	for _, failure := range []string{"listing", "manifest", "metadata"} {
		t.Run(failure, func(t *testing.T) {
			fixture := newRefreshRegistry(t)
			state := snapshot{ID: "sha256:" + strings.Repeat("1", 64), System: "x86_64-linux"}
			old := testCacheEntry(t, strings.Repeat("a", 32), "root", []byte("old"))
			oldTag := fixture.publish(t, state, old)
			newEntry := testCacheEntry(t, strings.Repeat("b", 32), "root", []byte("new"))
			newTag := fixture.publish(t, state, newEntry)
			other := testCacheEntry(t, strings.Repeat("c", 32), "root", []byte("other"))
			otherTag := fixture.publish(t, state, other)
			newManifest, err := fixture.client.getManifest(context.Background(), newTag)
			if err != nil {
				t.Fatal(err)
			}
			index := newCacheIndex(fixture.client, state.System)
			fixture.list(oldTag)
			if _, err := index.refresh(context.Background()); err != nil {
				t.Fatal(err)
			}
			fixture.list(newTag, otherTag)
			fixture.mu.Lock()
			switch failure {
			case "listing":
				fixture.failPath = "/v2/cache/tags/list"
			case "manifest":
				fixture.failPath = "/v2/cache/manifests/" + newTag
			case "metadata":
				fixture.failPath = "/v2/cache/blobs/" + newManifest.Metadata.Digest.String()
			}
			fixture.mu.Unlock()
			if _, err := index.refresh(context.Background()); err == nil {
				t.Fatal("expected refresh failure")
			}
			if len(index.segments) != 1 || index.segments[oldTag].Tag != oldTag ||
				len(index.entries) != 1 || index.entries[strings.Repeat("a", 32)].NARInfo != old.NARInfo ||
				len(index.nars) != 1 || index.nars[old.NARURL].NARDigest != old.NARDigest {
				t.Fatal("failed refresh changed committed state")
			}
			fixture.mu.Lock()
			fixture.failPath = ""
			fixture.mu.Unlock()
			fixture.list(newTag, otherTag)
			if count, err := index.refresh(context.Background()); err != nil || count != 2 {
				t.Fatalf("recovery: count=%d err=%v", count, err)
			}
			if index.entries[strings.Repeat("b", 32)].NARInfo != newEntry.NARInfo ||
				index.entries[strings.Repeat("c", 32)].NARInfo != other.NARInfo || len(index.segments) != 2 {
				t.Fatal("recovery did not replace the index")
			}
		})
	}
}

func TestCacheRefreshRetriesDisappearedTag(t *testing.T) {
	fixture := newRefreshRegistry(t)
	state := snapshot{ID: "sha256:" + strings.Repeat("1", 64), System: "x86_64-linux"}
	entry := testCacheEntry(t, strings.Repeat("a", 32), "root", []byte("nar"))
	tag := fixture.publish(t, state, entry)
	fixture.list(tag)
	fixture.mu.Lock()
	fixture.missingTag = tag
	fixture.mu.Unlock()
	index := newCacheIndex(fixture.client, state.System)
	if count, err := index.refresh(context.Background()); err != nil || count != 0 {
		t.Fatalf("disappeared tag: count=%d err=%v", count, err)
	}
	fixture.assertReads(t, 1, 0)
	fixture.mu.Lock()
	fixture.missingTag = ""
	fixture.mu.Unlock()
	fixture.list(tag)
	if count, err := index.refresh(context.Background()); err != nil || count != 1 {
		t.Fatalf("reappeared tag: count=%d err=%v", count, err)
	}
	fixture.assertReads(t, 1, 1)
}

func TestCacheRefreshDeterministicWinnerAfterDeletion(t *testing.T) {
	fixture := newRefreshRegistry(t)
	hash := strings.Repeat("a", 32)
	old := testCacheEntry(t, hash, "root", []byte("old"))
	newEntry := testCacheEntry(t, hash, "root", []byte("new"))
	state := snapshot{ID: "sha256:" + strings.Repeat("1", 64), System: "x86_64-linux"}
	index := newCacheIndex(fixture.client, state.System)
	prefix := segmentTagPrefix(state.ID, state.System)
	for _, item := range []struct {
		tag     string
		created int64
		entry   cacheEntry
	}{
		{prefix + "z", 1, old},
		{prefix + "a", 2, old},
		{prefix + "b", 2, newEntry},
	} {
		index.segments[item.tag] = segmentRef{Tag: item.tag, segment: segment{
			Snapshot: state.ID, System: state.System, CreatedAt: time.Unix(item.created, 0),
			Entries: map[string]cacheEntry{hash: item.entry},
		}}
	}
	fixture.list(prefix+"b", prefix+"z", prefix+"a")
	if _, err := index.refresh(context.Background()); err != nil {
		t.Fatal(err)
	}
	fixture.assertReads(t, 0, 0)
	if index.entries[hash].NARDigest != newEntry.NARDigest {
		t.Fatal("newest time and tag did not win")
	}
	if len(index.nars) != 2 || index.nars[old.NARURL].NARDigest != old.NARDigest {
		t.Fatal("refresh invalidated a NAR URL from a retained segment")
	}
	response := httptest.NewRecorder()
	index.serveHTTP(response, httptest.NewRequest(http.MethodHead, "/"+old.NARURL, nil))
	if response.Code != http.StatusOK {
		t.Fatalf("old NAR URL status=%d", response.Code)
	}
	fixture.list(prefix+"a", prefix+"z")
	if _, err := index.refresh(context.Background()); err != nil {
		t.Fatal(err)
	}
	fixture.assertReads(t, 0, 0)
	if index.entries[hash].NARDigest != old.NARDigest || len(index.nars) != 1 {
		t.Fatal("remaining older entry was not restored")
	}
	if _, ok := index.nars[newEntry.NARURL]; ok {
		t.Fatal("deleted winning NAR is still indexed")
	}
}

func TestRefreshKeepsPreviouslyIssuedNARURL(t *testing.T) {
	fixture := newRefreshRegistry(t)
	state := snapshot{ID: "sha256:" + strings.Repeat("1", 64), System: "x86_64-linux"}
	hash := strings.Repeat("a", 32)
	old := testCacheEntry(t, hash, "root", []byte("old compressed nar"))
	oldTag := fixture.publish(t, state, old)
	index := newCacheIndex(fixture.client, state.System)
	fixture.list(oldTag)
	if _, err := index.refresh(context.Background()); err != nil {
		t.Fatal(err)
	}
	info := httptest.NewRecorder()
	index.serveHTTP(info, httptest.NewRequest(http.MethodGet, "/"+hash+".narinfo", nil))
	if info.Code != http.StatusOK || !strings.Contains(info.Body.String(), "URL: "+old.NARURL) {
		t.Fatal("old narinfo was not served")
	}
	newEntry := testCacheEntry(t, hash, "root", []byte("new compressed nar"))
	newTag := fixture.publish(t, state, newEntry)
	fixture.list(oldTag, newTag)
	if _, err := index.refresh(context.Background()); err != nil {
		t.Fatal(err)
	}
	response := httptest.NewRecorder()
	index.serveHTTP(response, httptest.NewRequest(http.MethodGet, "/"+old.NARURL, nil))
	if response.Code != http.StatusOK || response.Body.String() != "old compressed nar" {
		t.Fatalf("previously issued URL: status=%d body=%q", response.Code, response.Body.String())
	}
}

func TestServeCacheReturnsBadGatewayBeforeWritingNARHeaders(t *testing.T) {
	client := testRegistryClient(t)
	index := newCacheIndex(client, "x86_64-linux")
	index.nars["nar/missing.nar.zst"] = cacheEntry{
		NARURL:    "nar/missing.nar.zst",
		NARDigest: "sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
		NARSize:   42,
	}

	request := httptest.NewRequest(http.MethodGet, "/nar/missing.nar.zst", nil)
	response := httptest.NewRecorder()
	index.serveHTTP(response, request)
	if response.Code != http.StatusBadGateway {
		t.Fatalf("status=%d", response.Code)
	}
}
