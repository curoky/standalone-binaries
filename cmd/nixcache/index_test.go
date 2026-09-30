package main

import (
	"bytes"
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/opencontainers/go-digest"
)

func TestFrozenIndexRoundTrip(t *testing.T) {
	fixture := newRefreshRegistry(t)
	state := snapshot{ID: "sha256:" + strings.Repeat("1", 64), System: "x86_64-linux"}
	hash := strings.Repeat("a", 32)
	oldEntry := testCacheEntry(t, hash, "root", []byte("old compressed nar"))
	oldTag := fixture.publish(t, state, oldEntry)
	time.Sleep(time.Millisecond)
	newEntry := testCacheEntry(t, hash, "root", []byte("new compressed nar"))
	newTag := fixture.publish(t, state, newEntry)
	fixture.list(oldTag, newTag)

	firstPath := filepath.Join(t.TempDir(), "index.json")
	if err := createFrozenIndex(context.Background(), fixture.client, state.System, firstPath); err != nil {
		t.Fatal(err)
	}
	fixture.assertReads(t, 2, 2)
	first, err := os.ReadFile(firstPath)
	if err != nil {
		t.Fatal(err)
	}
	if bytes.Contains(first, []byte("narPath")) || len(first) == 0 || first[len(first)-1] != '\n' {
		t.Fatalf("unexpected frozen index encoding: %q", first)
	}

	fixture.list(oldTag, newTag)
	secondPath := filepath.Join(t.TempDir(), "index.json")
	if err := createFrozenIndex(context.Background(), fixture.client, state.System, secondPath); err != nil {
		t.Fatal(err)
	}
	second, err := os.ReadFile(secondPath)
	if err != nil {
		t.Fatal(err)
	}
	if !bytes.Equal(first, second) {
		t.Fatal("repeated index generation was not deterministic")
	}

	fixture.list(oldTag, newTag)
	current, err := loadFrozenIndex(firstPath, state.System)
	if err != nil {
		t.Fatal(err)
	}
	if current.entries[hash].NARInfo != newEntry.NARInfo {
		t.Fatal("frozen index did not retain the newest narinfo")
	}
	if len(current.nars) != 2 || current.nars[oldEntry.NARURL].Digest != oldEntry.NARDigest {
		t.Fatal("frozen index did not retain an older NAR descriptor")
	}
	index := newCacheIndex(fixture.client, state.System)
	index.current.Store(current)
	for _, entry := range []cacheEntry{oldEntry, newEntry} {
		response := httptest.NewRecorder()
		index.serveHTTP(response, httptest.NewRequest(http.MethodGet, "/"+entry.NARURL, nil))
		want := map[string]string{oldEntry.NARURL: "old compressed nar", newEntry.NARURL: "new compressed nar"}[entry.NARURL]
		if response.Code != http.StatusOK || response.Body.String() != want {
			t.Fatalf("serve %s: status=%d body=%q want=%q", entry.NARURL, response.Code, response.Body.String(), want)
		}
	}
	fixture.mu.Lock()
	defer fixture.mu.Unlock()
	if fixture.requests["/v2/cache/tags/list"] != 0 {
		t.Fatal("loading a frozen index listed remote tags")
	}
	for requestPath := range fixture.requests {
		if strings.HasPrefix(requestPath, "/v2/cache/manifests/") {
			t.Fatalf("loading a frozen index fetched metadata manifest %s", requestPath)
		}
	}
}

func TestFrozenIndexEmptyCache(t *testing.T) {
	fixture := newRefreshRegistry(t)
	fixture.list()
	filePath := filepath.Join(t.TempDir(), "empty.json")
	if err := createFrozenIndex(context.Background(), fixture.client, "x86_64-linux", filePath); err != nil {
		t.Fatal(err)
	}
	current, err := loadFrozenIndex(filePath, "x86_64-linux")
	if err != nil {
		t.Fatal(err)
	}
	if len(current.entries) != 0 || len(current.nars) != 0 {
		t.Fatalf("empty frozen index=%+v", current)
	}
}

func TestLoadFrozenIndexValidation(t *testing.T) {
	system := "x86_64-linux"
	hash := strings.Repeat("a", 32)
	entry := testCacheEntry(t, hash, "root", []byte("compressed nar"))
	extraURL := "nar/extra.nar.zst"
	extraBlob := narBlob{Digest: digest.FromString("extra").String(), Size: 5}

	newValid := func() frozenIndex {
		return frozenIndex{
			Version: frozenIndexVersion,
			System:  system,
			Entries: map[string]cacheEntry{hash: entry},
			NARs: map[string]narBlob{
				entry.NARURL: {Digest: entry.NARDigest, Size: entry.NARSize},
				extraURL:     extraBlob,
			},
		}
	}
	tests := []struct {
		name    string
		mutate  func(*frozenIndex)
		rewrite func([]byte) []byte
		want    string
	}{
		{name: "version", mutate: func(index *frozenIndex) { index.Version++ }, want: "unsupported frozen cache index version"},
		{name: "system", mutate: func(index *frozenIndex) { index.System = "aarch64-linux" }, want: "does not match current system"},
		{name: "null entries", mutate: func(index *frozenIndex) { index.Entries = nil }, want: "must be JSON objects"},
		{name: "null nars", mutate: func(index *frozenIndex) { index.NARs = nil }, want: "must be JSON objects"},
		{name: "entry hash", mutate: func(index *frozenIndex) {
			delete(index.Entries, hash)
			index.Entries[strings.Repeat("b", 32)] = entry
		}, want: "does not match store path hash"},
		{name: "entry URL", mutate: func(index *frozenIndex) {
			changed := entry
			changed.NARURL = extraURL
			index.Entries[hash] = changed
			index.NARs[extraURL] = narBlob{Digest: changed.NARDigest, Size: changed.NARSize}
		}, want: "metadata does not match narinfo"},
		{name: "entry digest", mutate: func(index *frozenIndex) {
			changed := entry
			changed.NARDigest = extraBlob.Digest
			index.Entries[hash] = changed
			index.NARs[changed.NARURL] = narBlob{Digest: changed.NARDigest, Size: changed.NARSize}
		}, want: "metadata does not match narinfo"},
		{name: "entry size", mutate: func(index *frozenIndex) {
			changed := entry
			changed.NARSize++
			index.Entries[hash] = changed
			index.NARs[changed.NARURL] = narBlob{Digest: changed.NARDigest, Size: changed.NARSize}
		}, want: "metadata does not match narinfo"},
		{name: "malformed narinfo", mutate: func(index *frozenIndex) {
			changed := entry
			changed.NARInfo = "not narinfo"
			index.Entries[hash] = changed
		}, want: "invalid narinfo"},
		{name: "missing entry descriptor", mutate: func(index *frozenIndex) { delete(index.NARs, entry.NARURL) }, want: "has no NAR descriptor"},
		{name: "mismatched entry descriptor", mutate: func(index *frozenIndex) {
			index.NARs[entry.NARURL] = extraBlob
		}, want: "does not match NAR descriptor"},
		{name: "extra descriptor URL", mutate: func(index *frozenIndex) {
			delete(index.NARs, extraURL)
			index.NARs["../extra"] = extraBlob
		}, want: "invalid NAR descriptor URL"},
		{name: "extra descriptor digest", mutate: func(index *frozenIndex) {
			index.NARs[extraURL] = narBlob{Digest: "sha512:" + strings.Repeat("a", 128), Size: 5}
		}, want: "invalid digest or size"},
		{name: "extra descriptor size", mutate: func(index *frozenIndex) {
			index.NARs[extraURL] = narBlob{Digest: extraBlob.Digest}
		}, want: "invalid digest or size"},
		{name: "unknown top-level field", rewrite: func(body []byte) []byte {
			return bytes.Replace(body, []byte(`"version":1`), []byte(`"unknown":true,"version":1`), 1)
		}, want: "unknown field"},
		{name: "unknown entry field", rewrite: func(body []byte) []byte {
			return bytes.Replace(body, []byte(`"storePath"`), []byte(`"unknown":true,"storePath"`), 1)
		}, want: "unknown field"},
		{name: "unknown descriptor field", rewrite: func(body []byte) []byte {
			return bytes.Replace(body, []byte(`"digest"`), []byte(`"unknown":true,"digest"`), 1)
		}, want: "unknown field"},
		{name: "trailing JSON", rewrite: func(body []byte) []byte { return append(body, []byte(`{}`)...) }, want: "multiple JSON values"},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			index := newValid()
			if test.mutate != nil {
				test.mutate(&index)
			}
			body, err := json.Marshal(index)
			if err != nil {
				t.Fatal(err)
			}
			if test.rewrite != nil {
				body = test.rewrite(body)
			}
			filePath := filepath.Join(t.TempDir(), "index.json")
			if err := os.WriteFile(filePath, body, 0o644); err != nil {
				t.Fatal(err)
			}
			if _, err := loadFrozenIndex(filePath, system); err == nil || !strings.Contains(err.Error(), test.want) {
				t.Fatalf("error=%v, want substring %q", err, test.want)
			}
		})
	}
}

func TestLoadFrozenIndexSizeLimit(t *testing.T) {
	filePath := filepath.Join(t.TempDir(), "index.json")
	file, err := os.Create(filePath)
	if err != nil {
		t.Fatal(err)
	}
	if err := file.Truncate(maxMetadataSize + 1); err != nil {
		t.Fatal(err)
	}
	if err := file.Close(); err != nil {
		t.Fatal(err)
	}
	if _, err := loadFrozenIndex(filePath, "x86_64-linux"); err == nil || !strings.Contains(err.Error(), "exceeds limit") {
		t.Fatalf("error=%v", err)
	}
}

func TestFrozenIndexCommands(t *testing.T) {
	command := newCommand()
	index, _, err := command.Find([]string{"index"})
	if err != nil || index.Use != "index <path>" {
		t.Fatalf("index command: use=%q err=%v", index.Use, err)
	}
	serve, _, err := command.Find([]string{"serve"})
	if err != nil {
		t.Fatal(err)
	}
	if flag := serve.Flags().Lookup("index"); flag == nil || flag.DefValue != "" {
		t.Fatal("serve --index flag is missing or has a non-empty default")
	}
}

func TestLoadFrozenIndexAcceptsWhitespaceAfterDocument(t *testing.T) {
	filePath := filepath.Join(t.TempDir(), "index.json")
	body := `{"version":1,"system":"x86_64-linux","entries":{},"nars":{}}` + "\n\t "
	if err := os.WriteFile(filePath, []byte(body), 0o644); err != nil {
		t.Fatal(err)
	}
	current, err := loadFrozenIndex(filePath, "x86_64-linux")
	if err != nil {
		t.Fatal(err)
	}
	if len(current.entries) != 0 || len(current.nars) != 0 {
		t.Fatal("empty index was not preserved")
	}
}
