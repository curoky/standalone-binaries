package main

import (
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func testRoots() cacheRoots {
	roots := make(cacheRoots)
	for _, system := range cacheSystems {
		roots[system] = map[string]packageRoots{"root": {
			Out:     "/nix/store/" + strings.Repeat("a", 32) + "-root",
			Archive: "/nix/store/" + strings.Repeat("b", 32) + "-archive",
			Sources: []string{"/nix/store/" + strings.Repeat("c", 32) + "-source"},
		}}
	}
	return roots
}

func TestLoadRootsRejectsIncompleteDocuments(t *testing.T) {
	valid, _ := json.Marshal(testRoots())
	for name, body := range map[string]string{
		"empty": "{}", "null": "null", "missing platforms": `{"x86_64-linux":{}}`,
		"extra document": string(valid) + " {}",
		"unknown field":  strings.Replace(string(valid), `"out":`, `"unknown":`, 1),
		"invalid path":   strings.Replace(string(valid), "/nix/store/", "/tmp/", 1),
		"no sources":     strings.Replace(string(valid), `"sources":["/nix/store/`+strings.Repeat("c", 32)+`-source"]`, `"sources":[]`, 1),
	} {
		t.Run(name, func(t *testing.T) {
			path := filepath.Join(t.TempDir(), "roots.json")
			if err := os.WriteFile(path, []byte(body), 0600); err != nil {
				t.Fatal(err)
			}
			if _, err := loadRoots(path); err == nil {
				t.Fatal("accepted incomplete roots")
			}
		})
	}
	path := filepath.Join(t.TempDir(), "roots.json")
	if err := os.WriteFile(path, valid, 0600); err != nil {
		t.Fatal(err)
	}
	if _, err := loadRoots(path); err != nil {
		t.Fatal(err)
	}
}

func TestLoadRootsRejectsOversizedFile(t *testing.T) {
	file, err := os.CreateTemp(t.TempDir(), "roots-*.json")
	if err != nil {
		t.Fatal(err)
	}
	defer file.Close()
	if err := file.Truncate(maxMetadataSize + 1); err != nil {
		t.Fatal(err)
	}
	if _, err := loadRoots(file.Name()); err == nil || !strings.Contains(err.Error(), "size limit") {
		t.Fatalf("oversized roots: %v", err)
	}
}

func TestRootsProtectCrossSnapshotClosure(t *testing.T) {
	root := testCacheEntry(t, strings.Repeat("a", 32), "root", []byte("root"))
	dependency := testCacheEntry(t, strings.Repeat("d", 32), "dependency", []byte("dependency"))
	root.NARInfo = strings.Replace(root.NARInfo, "References: \n", "References: "+strings.TrimPrefix(dependency.StorePath, "/nix/store/")+"\n", 1)
	first := ref("s1", "x86_64-linux", "alpha", "alpha-only", 1)
	first.Entries = map[string]cacheEntry{strings.Repeat("a", 32): root}
	dep := ref("s1", "x86_64-linux", "dependency", "dep", 2)
	dep.Entries = map[string]cacheEntry{strings.Repeat("d", 32): dependency}
	newest := dep
	newest.Tag = "dep-new"
	newest.CreatedAt = newest.CreatedAt.Add(1)
	segments := []segmentRef{first, dep, newest, ref("s2", "x86_64-linux", "beta", "beta", 4), ref("s3", "x86_64-linux", "gamma", "gamma", 5)}
	protected, err := protectedSegments(segments, testRoots())
	if err != nil {
		t.Fatal(err)
	}
	if !protected[first.Tag] || !protected[newest.Tag] || protected[dep.Tag] || len(protected) != 2 {
		t.Fatalf("protected=%v", protected)
	}
	candidates, _ := segmentsToDelete(segments, 2, 2, 2)
	found := false
	for _, item := range candidates {
		if item.Tag == first.Tag {
			found = protected[item.Tag]
		}
	}
	if !found {
		t.Fatal("old snapshot root was not rescued")
	}
	if _, err := protectedSegments([]segmentRef{first}, testRoots()); err == nil {
		t.Fatal("missing closure reference accepted")
	}
	if protected, err := protectedSegments(nil, testRoots()); err != nil || len(protected) != 0 {
		t.Fatalf("never-built roots: protected=%v err=%v", protected, err)
	}
}
