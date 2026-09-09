package main

import (
	"context"
	"net/http"
	"net/http/httptest"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
)

func TestDiscoveryCacheAndPublicationStates(t *testing.T) {
	bash, err := exec.LookPath("bash")
	if err != nil {
		t.Skip("bash is not available")
	}
	workflow, err := os.ReadFile("../../.github/workflows/build-platform.yaml")
	if err != nil {
		t.Fatal(err)
	}
	_, function, ok := strings.Cut(string(workflow), "          check() {")
	if !ok {
		t.Fatal("workflow discovery function is missing")
	}
	function, _, ok = strings.Cut(function, "          export -f check")
	if !ok {
		t.Fatal("workflow discovery function boundary is missing")
	}
	bin := filepath.Join(t.TempDir(), "bin")
	if err := os.Mkdir(bin, 0700); err != nil {
		t.Fatal(err)
	}
	helper := "#!/usr/bin/env bash\ncase $1 in\nprobe) [[ $2 != /nix/store/${MISS_ROOT:-none} ]] || exit 1; exit \"$PROBE_STATUS\" ;;\npublication) exit \"$PUBLICATION_STATUS\" ;;\nesac\n"
	if err := os.WriteFile(filepath.Join(bin, "nixcache"), []byte(helper), 0700); err != nil {
		t.Fatal(err)
	}
	t.Setenv("RUNNER_TEMP", filepath.Dir(bin))
	t.Setenv("SYSTEM", "x86_64-linux")
	t.Setenv("ARTIFACT_SUFFIX", "linux-x86_64")
	for _, test := range []struct {
		name, probe, publication, missRoot, want string
		wantError                                bool
	}{
		{"ready", "0", "0", "", "pkg\t1\t1\n", false},
		{"cache only", "0", "1", "", "pkg\t1\t0\n", false},
		{"publication only", "1", "0", "", "pkg\t0\t1\n", false},
		{"neither", "1", "1", "", "pkg\t0\t0\n", false},
		{"out missing", "0", "0", "out", "pkg\t0\t1\n", false},
		{"archive missing", "0", "0", "archive", "pkg\t0\t1\n", false},
		{"source missing", "0", "0", "source", "pkg\t0\t1\n", false},
		{"second source missing", "0", "0", "source2", "pkg\t0\t1\n", false},
		{"cache error", "2", "0", "", "", true},
		{"publication error", "0", "2", "", "", true},
	} {
		t.Run(test.name, func(t *testing.T) {
			t.Setenv("PROBE_STATUS", test.probe)
			t.Setenv("PUBLICATION_STATUS", test.publication)
			t.Setenv("MISS_ROOT", test.missRoot)
			script := "check() {" + function + "\ncheck \"$1\""
			output, err := exec.Command(bash, "-c", script, "_", "pkg\t/nix/store/out\t/nix/store/archive\t/nix/store/source /nix/store/source2").CombinedOutput()
			if (err != nil) != test.wantError || string(output) != test.want {
				t.Fatalf("output=%q err=%v", output, err)
			}
		})
	}
}

func TestNixRoundTrip(t *testing.T) {
	storePaths := strings.Fields(os.Getenv("NIXCACHE_TEST_STORE_PATH"))
	if len(storePaths) == 0 {
		t.Skip("set NIXCACHE_TEST_STORE_PATH to run the Nix integration test")
	}
	nix, err := exec.LookPath("nix")
	if err != nil {
		t.Skip("nix is not available")
	}

	client := testRegistryClient(t)
	repoRoot, err := filepath.Abs(filepath.Join("..", ".."))
	if err != nil {
		t.Fatal(err)
	}
	if err := pushPaths(context.Background(), client, repoRoot, "integration-test", storePaths); err != nil {
		t.Fatal(err)
	}

	t.Chdir(t.TempDir())
	index := newCacheIndex(client, currentSystem())
	if _, err := index.refresh(context.Background()); err != nil {
		t.Fatal(err)
	}
	index.ready.Store(true)
	server := httptest.NewServer(http.HandlerFunc(index.serveHTTP))
	t.Cleanup(server.Close)

	destination := "file://" + filepath.Join(t.TempDir(), "cache")
	args := []string{"copy", "--no-check-sigs", "--from", server.URL, "--to", destination}
	command := exec.Command(nix, append(args, storePaths...)...)
	command.Stdout = os.Stdout
	command.Stderr = os.Stderr
	if err := command.Run(); err != nil {
		t.Fatal(err)
	}

	cacheDir := strings.TrimPrefix(destination, "file://")
	for _, storePath := range storePaths {
		hash, err := storeHash(storePath)
		if err != nil {
			t.Fatal(err)
		}
		if _, err := os.Stat(filepath.Join(cacheDir, hash+".narinfo")); err != nil {
			t.Fatalf("copied narinfo is missing for %s: %v", storePath, err)
		}
	}
}
