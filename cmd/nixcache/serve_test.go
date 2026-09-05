package main

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log"
	"net"
	"net/http"
	"net/http/httptest"
	"os"
	"os/exec"
	"strconv"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/google/go-containerregistry/pkg/registry"
	"github.com/opencontainers/go-digest"
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

func newRefreshRegistry(t testing.TB) *refreshRegistry {
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
	if _, ok := index.current.Load().nars[old.NARURL]; ok {
		t.Fatal("deleted segment NAR is still indexed")
	}
	if hit, err := probeStorePath(context.Background(), http.DefaultClient, server.URL, old.StorePath); err != nil || hit {
		t.Fatalf("probe deleted path: hit=%t err=%v", hit, err)
	}

	fixture.list(newTag, prefixTag)
	if _, err := index.refresh(context.Background()); err == nil {
		t.Fatal("expected mismatched platform metadata to fail")
	}
	if len(index.segments) != 1 || len(index.current.Load().entries) != 1 {
		t.Fatal("platform mismatch changed the index")
	}

	fixture.list()
	if count, err := index.refresh(context.Background()); err != nil || count != 0 {
		t.Fatalf("empty refresh: count=%d err=%v", count, err)
	}
	fixture.assertReads(t, 0, 0)
	if len(index.segments) != 0 || len(index.current.Load().nars) != 0 {
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
				len(index.current.Load().entries) != 1 || index.current.Load().entries[strings.Repeat("a", 32)] != old.NARInfo ||
				len(index.current.Load().nars) != 1 || index.current.Load().nars[old.NARURL].digest != old.NARDigest {
				t.Fatal("failed refresh changed committed state")
			}
			fixture.mu.Lock()
			fixture.failPath = ""
			fixture.mu.Unlock()
			fixture.list(newTag, otherTag)
			if count, err := index.refresh(context.Background()); err != nil || count != 2 {
				t.Fatalf("recovery: count=%d err=%v", count, err)
			}
			if index.current.Load().entries[strings.Repeat("b", 32)] != newEntry.NARInfo ||
				index.current.Load().entries[strings.Repeat("c", 32)] != other.NARInfo || len(index.segments) != 2 {
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
	if index.current.Load().entries[hash] != newEntry.NARInfo {
		t.Fatal("newest time and tag did not win")
	}
	if len(index.current.Load().nars) != 2 || index.current.Load().nars[old.NARURL].digest != old.NARDigest {
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
	if index.current.Load().entries[hash] != old.NARInfo || len(index.current.Load().nars) != 1 {
		t.Fatal("remaining older entry was not restored")
	}
	if _, ok := index.current.Load().nars[newEntry.NARURL]; ok {
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

func TestServeListen(t *testing.T) {
	for _, host := range []string{"127.0.0.1", "::1"} {
		t.Run(host, func(t *testing.T) {
			listener, err := (serveConfig{host: host, port: 0}).listen()
			if err != nil {
				t.Fatal(err)
			}
			defer func() { _ = listener.Close() }() // Server.Serve also closes the listener.
			address := listener.Addr().(*net.TCPAddr)
			if !address.IP.Equal(net.ParseIP(host)) || address.Port == 0 {
				t.Fatalf("address=%v", address)
			}
			server := &http.Server{Handler: http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) { w.WriteHeader(http.StatusNoContent) })}
			done := make(chan error, 1)
			go func() { done <- server.Serve(listener) }()
			defer func() {
				if err := server.Close(); err != nil {
					t.Error(err)
				}
				if err := <-done; !errors.Is(err, http.ErrServerClosed) {
					t.Errorf("serve: %v", err)
				}
			}()
			response, err := http.Get("http://" + listener.Addr().String())
			if err != nil {
				t.Fatal(err)
			}
			if err := response.Body.Close(); err != nil {
				t.Fatal(err)
			}
			if response.StatusCode != http.StatusNoContent {
				t.Fatalf("status=%d", response.StatusCode)
			}
			command := newCommand()
			command.SetArgs([]string{"serve", "--host", host, "--port", strconv.Itoa(address.Port)})
			if err := command.Execute(); err == nil || !strings.Contains(err.Error(), listener.Addr().String()) {
				t.Fatalf("CLI did not bind requested address: %v", err)
			}
		})
	}
	for _, port := range []int{-1, 65536} {
		command := newCommand()
		command.SetArgs([]string{"serve", "--port", strconv.Itoa(port)})
		if err := command.Execute(); err == nil || !strings.Contains(err.Error(), "port must be") {
			t.Fatalf("invalid port %d: %v", port, err)
		}
	}
	command, _, err := newCommand().Find([]string{"serve"})
	if err != nil {
		t.Fatal(err)
	}
	if command.Flags().Lookup("host").DefValue != "127.0.0.1" || command.Flags().Lookup("port").DefValue != "37515" {
		t.Fatal("default listen address changed")
	}
}

func TestCacheReadinessAndConcurrentRefresh(t *testing.T) {
	fixture := newRefreshRegistry(t)
	index := newCacheIndex(fixture.client, "x86_64-linux")
	response := httptest.NewRecorder()
	index.serveHTTP(response, httptest.NewRequest(http.MethodGet, "/nix-cache-info", nil))
	if response.Code != http.StatusServiceUnavailable {
		t.Fatalf("initial readiness=%d", response.Code)
	}
	if _, err := index.refresh(context.Background()); err != nil {
		t.Fatal(err)
	}
	response = httptest.NewRecorder()
	index.serveHTTP(response, httptest.NewRequest(http.MethodGet, "/nix-cache-info", nil))
	if response.Code != http.StatusOK {
		t.Fatalf("empty cache readiness=%d", response.Code)
	}
	state := snapshot{ID: "sha256:" + strings.Repeat("1", 64), System: index.system}
	entry := testCacheEntry(t, strings.Repeat("a", 32), "root", []byte("nar"))
	tag := fixture.publish(t, state, entry)
	var readers sync.WaitGroup
	for range 8 {
		readers.Go(func() {
			for range 100 {
				for _, path := range []string{"/nix-cache-info", "/" + strings.Repeat("a", 32) + ".narinfo", "/" + entry.NARURL} {
					response := httptest.NewRecorder()
					index.serveHTTP(response, httptest.NewRequest(http.MethodHead, path, nil))
					if response.Code != http.StatusOK && (path == "/nix-cache-info" || response.Code != http.StatusNotFound) {
						t.Errorf("%s status=%d", path, response.Code)
					}
				}
			}
		})
	}
	defer readers.Wait()
	for i := range 20 {
		if i%2 == 0 {
			fixture.list(tag)
		} else {
			fixture.list()
		}
		if _, err := index.refresh(context.Background()); err != nil {
			t.Fatal(err)
		}
		current := index.current.Load()
		if _, err := index.refresh(context.Background()); err != nil {
			t.Fatal(err)
		}
		if index.current.Load() != current {
			t.Fatal("unchanged refresh rebuilt snapshot")
		}
	}
}

func TestServeMetadataHTTPBehavior(t *testing.T) {
	index := newCacheIndex(nil, "x86_64-linux")
	index.current.Store(&indexSnapshot{entries: map[string]string{"hash": "0123456789"}})
	for _, test := range []struct {
		method, path, rangeHeader, body string
		status                          int
	}{
		{http.MethodGet, "/hash.narinfo", "", "0123456789", 200},
		{http.MethodHead, "/hash.narinfo", "", "", 200},
		{http.MethodHead, "/nix-cache-info", "", "", 200},
		{http.MethodGet, "/hash.narinfo", "bytes=2-4", "234", 206},
		{http.MethodPost, "/hash.narinfo", "", "method not allowed\n", 405},
		{http.MethodGet, "/unknown", "", "404 page not found\n", 404},
	} {
		request := httptest.NewRequest(test.method, test.path, nil)
		request.Header.Set("Range", test.rangeHeader)
		response := httptest.NewRecorder()
		index.serveHTTP(response, request)
		if response.Code != test.status || response.Body.String() != test.body {
			t.Fatalf("%s %s: %d %q", test.method, test.path, response.Code, response.Body.String())
		}
	}
}

func TestAccessLogPreservesStreamingInterfaces(t *testing.T) {
	output := log.Writer()
	var logs bytes.Buffer
	log.SetOutput(&logs)
	defer log.SetOutput(output)
	server := httptest.NewServer(withAccessLog(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if _, ok := w.(io.ReaderFrom); !ok {
			t.Error("ReaderFrom hidden by access logger")
		}
		if _, ok := w.(http.Flusher); !ok {
			t.Error("Flusher hidden by access logger")
		}
		w.WriteHeader(http.StatusAccepted)
		if _, err := io.Copy(w, struct{ io.Reader }{strings.NewReader("streamed")}); err != nil {
			t.Error(err)
		}
	})))
	response, err := http.Get(server.URL)
	if err != nil {
		server.Close()
		t.Fatal(err)
	}
	body, err := io.ReadAll(response.Body)
	if closeErr := response.Body.Close(); closeErr != nil {
		t.Error(closeErr)
	}
	server.Close()
	if err != nil || response.StatusCode != http.StatusAccepted || string(body) != "streamed" {
		t.Fatalf("stream: %d %q %v", response.StatusCode, body, err)
	}
	if !strings.Contains(logs.String(), "-> 202") {
		t.Fatalf("log=%q", logs.String())
	}
}

func TestProbeCommandExitCodes(t *testing.T) {
	if os.Getenv("NIXCACHE_TEST_CLI") == "1" {
		os.Args = append([]string{"nixcache"}, strings.Split(os.Getenv("NIXCACHE_TEST_ARGS"), "\n")...)
		os.Exit(run())
	}
	entry := testCacheEntry(t, strings.Repeat("a", 32), "root", []byte("nar"))
	for _, test := range []struct{ status, exit int }{{200, 0}, {404, 1}, {403, 2}} {
		server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			w.WriteHeader(test.status)
			_, _ = io.WriteString(w, entry.NARInfo)
		}))
		command := exec.Command(os.Args[0], "-test.run=^TestProbeCommandExitCodes$")
		command.Env = append(os.Environ(), "NIXCACHE_TEST_CLI=1", "NIXCACHE_TEST_ARGS=probe\n--cache\n"+server.URL+"\n"+entry.StorePath)
		output, err := command.CombinedOutput()
		server.Close()
		if command.ProcessState.ExitCode() != test.exit {
			t.Fatalf("status=%d exit=%d err=%v output=%s", test.status, command.ProcessState.ExitCode(), err, output)
		}
	}
}

func BenchmarkNARStream(b *testing.B) {
	body := bytes.Repeat([]byte("nar"), 1<<18)
	backend := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Length", strconv.Itoa(len(body)))
		_, _ = w.Write(body)
	}))
	defer backend.Close()
	client, err := newRegistryClient(backend.Listener.Addr().String()+"/cache", true)
	if err != nil {
		b.Fatal(err)
	}
	index := newCacheIndex(client, "x86_64-linux")
	index.current.Store(&indexSnapshot{nars: map[string]narBlob{"nar/test": {digest: digest.FromBytes(body).String(), size: int64(len(body))}}})
	server := httptest.NewServer(withAccessLog(http.HandlerFunc(index.serveHTTP)))
	defer server.Close()
	output := log.Writer()
	log.SetOutput(io.Discard)
	defer log.SetOutput(output)
	b.SetBytes(int64(len(body)))
	b.ReportAllocs()
	for b.Loop() {
		response, err := http.Get(server.URL + "/nar/test")
		if err != nil {
			b.Fatal(err)
		}
		n, err := io.Copy(io.Discard, response.Body)
		closeErr := response.Body.Close()
		if err != nil || closeErr != nil || n != int64(len(body)) || response.StatusCode != http.StatusOK {
			b.Fatalf("stream: bytes=%d status=%d err=%v close=%v", n, response.StatusCode, err, closeErr)
		}
	}
}

func BenchmarkCacheRefresh(b *testing.B) {
	output := log.Writer()
	log.SetOutput(io.Discard)
	b.Cleanup(func() { log.SetOutput(output) })
	for _, changed := range []bool{false, true} {
		b.Run(fmt.Sprintf("changed=%t", changed), func(b *testing.B) {
			fixture := newRefreshRegistry(b)
			index := newCacheIndex(fixture.client, "x86_64-linux")
			tags := make([]string, 256)
			for i := range tags {
				tags[i] = fmt.Sprintf("v1-snapshot-x86_64-linux-%d", i)
				entries := make(map[string]cacheEntry, 256)
				for j := range 256 {
					hash := fmt.Sprintf("%032x", i*64+j)
					entries[hash] = cacheEntry{StorePath: "/nix/store/" + hash + "-pkg", NARURL: "nar/" + hash, NARDigest: "sha256:" + hash + hash, NARSize: 1024, NARInfo: strings.Repeat("x", 512)}
				}
				index.segments[tags[i]] = segmentRef{Tag: tags[i], segment: segment{System: index.system, Snapshot: "snapshot", CreatedAt: time.Unix(int64(i), 0), Entries: entries}}
			}
			fixture.list(tags...)
			if _, err := index.refresh(context.Background()); err != nil {
				b.Fatal(err)
			}
			b.ReportAllocs()
			b.ResetTimer()
			for b.Loop() {
				if changed {
					index.segments["removed"] = segmentRef{Tag: "removed"}
				}
				if _, err := index.refresh(context.Background()); err != nil {
					b.Fatal(err)
				}
			}
		})
	}
}

func BenchmarkServeNarInfo(b *testing.B) {
	index := newCacheIndex(nil, "x86_64-linux")
	hash := strings.Repeat("a", 32)
	index.current.Store(&indexSnapshot{entries: map[string]string{hash: strings.Repeat("x", 1024)}})
	request := httptest.NewRequest(http.MethodGet, "/"+hash+".narinfo", nil)
	b.ReportAllocs()
	b.RunParallel(func(pb *testing.PB) {
		for pb.Next() {
			index.serveHTTP(httptest.NewRecorder(), request)
		}
	})
}

func TestRefreshRejectsConflictingNARURL(t *testing.T) {
	fixture := newRefreshRegistry(t)
	state := snapshot{ID: "sha256:" + strings.Repeat("1", 64), System: "x86_64-linux"}
	entry := testCacheEntry(t, strings.Repeat("a", 32), "root", []byte("nar"))
	tag := fixture.publish(t, state, entry)
	fixture.list(tag)
	index := newCacheIndex(fixture.client, state.System)
	if _, err := index.refresh(context.Background()); err != nil {
		t.Fatal(err)
	}
	other := testCacheEntry(t, strings.Repeat("b", 32), "other", []byte("other"))
	other.NARInfo = strings.ReplaceAll(other.NARInfo, other.NARURL, entry.NARURL)
	other.NARURL = entry.NARURL
	otherTag := fixture.publish(t, state, other)
	fixture.list(tag, otherTag)
	if _, err := index.refresh(context.Background()); err == nil || !strings.Contains(err.Error(), "conflicting NAR URL") {
		t.Fatalf("expected conflicting URL error, got %v", err)
	}
	response := httptest.NewRecorder()
	index.serveHTTP(response, httptest.NewRequest(http.MethodGet, "/"+entry.NARURL, nil))
	if response.Code != http.StatusOK || response.Body.String() != "nar" {
		t.Fatalf("previous index changed: %d %q", response.Code, response.Body.String())
	}
}

func TestServeCacheReturnsBadGatewayBeforeWritingNARHeaders(t *testing.T) {
	client := testRegistryClient(t)
	index := newCacheIndex(client, "x86_64-linux")
	index.current.Store(&indexSnapshot{nars: map[string]narBlob{
		"nar/missing.nar.zst": {digest: "sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", size: 42},
	}})

	request := httptest.NewRequest(http.MethodGet, "/nar/missing.nar.zst", nil)
	response := httptest.NewRecorder()
	index.serveHTTP(response, request)
	if response.Code != http.StatusBadGateway {
		t.Fatalf("status=%d", response.Code)
	}
}
