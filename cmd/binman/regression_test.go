package main

import (
	"archive/tar"
	"bytes"
	"fmt"
	"io"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"sync/atomic"
	"testing"

	"github.com/google/go-containerregistry/pkg/name"
	"github.com/google/go-containerregistry/pkg/v1/empty"
	"github.com/google/go-containerregistry/pkg/v1/mutate"
	"github.com/google/go-containerregistry/pkg/v1/remote"
	"github.com/google/go-containerregistry/pkg/v1/tarball"
)

func TestInstallReconcilesWithoutDownload(t *testing.T) {
	const arch = "linux-x86_64"
	var downloads atomic.Int32
	c := startRegistryWithMiddleware(t, arch, func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			if r.Method == http.MethodGet && strings.Contains(r.URL.Path, "/blobs/") {
				downloads.Add(1)
			}
			next.ServeHTTP(w, r)
		})
	}, "tool")
	t.Setenv("XDG_CACHE_HOME", t.TempDir())
	prefix := t.TempDir()
	opts := installOpts{prefix: prefix, arch: arch, linked: true}
	if err := c.installPackages([]string{"tool"}, opts); err != nil {
		t.Fatal(err)
	}
	link := filepath.Join(prefix, "bin", "tool")
	for _, replacement := range []string{"missing", "wrong"} {
		if err := os.Remove(link); err != nil {
			t.Fatal(err)
		}
		if replacement == "wrong" {
			if err := os.Symlink("wrong", link); err != nil {
				t.Fatal(err)
			}
		}
		downloads.Store(0)
		if err := c.installPackages([]string{"tool"}, opts); err != nil {
			t.Fatal(err)
		}
		if downloads.Load() != 0 {
			t.Fatal("matching digest downloaded again")
		}
		if _, err := os.Stat(link); err != nil {
			t.Fatal(err)
		}
	}
	opts.force = true
	if err := c.installPackages([]string{"tool"}, opts); err != nil {
		t.Fatal(err)
	}
	if downloads.Load() != 1 {
		t.Fatalf("force downloads=%d want 1", downloads.Load())
	}
	opts.force, opts.linked = false, false
	if err := c.installPackages([]string{"tool"}, opts); err != nil {
		t.Fatal(err)
	}
	if _, err := os.Lstat(link); !os.IsNotExist(err) {
		t.Fatalf("link remains: %v", err)
	}
}

func TestCorruptedDownloadPreservesCacheAndStore(t *testing.T) {
	const arch = "linux-x86_64"
	var corrupt atomic.Bool
	c := startRegistryWithMiddleware(t, arch, func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			if !corrupt.Load() || r.Method != http.MethodGet || !strings.Contains(r.URL.Path, "/blobs/") {
				next.ServeHTTP(w, r)
				return
			}
			recorder := httptest.NewRecorder()
			next.ServeHTTP(recorder, r)
			for key, values := range recorder.Header() {
				w.Header()[key] = values
			}
			body := recorder.Body.Bytes()
			if len(body) > 0 {
				body[len(body)/2] ^= 1
			}
			w.WriteHeader(recorder.Code)
			_, _ = w.Write(body)
		})
	}, "tool")
	t.Setenv("XDG_CACHE_HOME", t.TempDir())
	prefix := t.TempDir()
	opts := installOpts{prefix: prefix, arch: arch, linked: true}
	if err := c.installPackages([]string{"tool"}, opts); err != nil {
		t.Fatal(err)
	}
	cache := cachePath(arch, "tool")
	before, err := os.ReadFile(cache)
	if err != nil {
		t.Fatal(err)
	}
	metadata, err := readMeta(prefix, "tool")
	if err != nil {
		t.Fatal(err)
	}
	corrupt.Store(true)
	opts.force = true
	if err := c.installPackages([]string{"tool"}, opts); err == nil {
		t.Fatal("corrupted blob accepted")
	}
	after, err := os.ReadFile(cache)
	if err != nil || !bytes.Equal(before, after) {
		t.Fatalf("cache changed on failed download: %v", err)
	}
	current, err := readMeta(prefix, "tool")
	if err != nil || metadata != current {
		t.Fatalf("store changed on failed download: %v", err)
	}
	if _, err := os.Stat(filepath.Join(prefix, "bin", "tool")); err != nil {
		t.Fatalf("link lost on failed download: %v", err)
	}
}

func TestExtractArchiveBoundaries(t *testing.T) {
	for _, test := range []struct {
		name    string
		entries []archiveEntry
	}{
		{"traversal", []archiveEntry{{name: "../outside", body: "bad"}}},
		{"absolute", []archiveEntry{{name: "/outside", body: "bad"}}},
		{"hardlink escape", []archiveEntry{{name: "link", typeflag: tar.TypeLink, linkname: "pkg/../outside"}}},
		{"symlink parent", []archiveEntry{
			{name: "dir/target", body: "keep"},
			{name: "alias", typeflag: tar.TypeSymlink, linkname: "dir"},
			{name: "alias/target", body: "bad"},
		}},
		{"hardlink symlink parent", []archiveEntry{
			{name: "dir/target", body: "keep"},
			{name: "alias", typeflag: tar.TypeSymlink, linkname: "dir"},
			{name: "link", typeflag: tar.TypeLink, linkname: "pkg/alias/target"},
		}},
		{"unsupported", []archiveEntry{{name: "pipe", typeflag: tar.TypeFifo}}},
	} {
		t.Run(test.name, func(t *testing.T) {
			root := t.TempDir()
			archive := filepath.Join(root, "pkg.tar.gz")
			if err := os.WriteFile(archive, archiveTarGz(t, "pkg", test.entries...), 0o600); err != nil {
				t.Fatal(err)
			}
			if err := extractTarGz(archive, filepath.Join(root, "store")); err == nil {
				t.Fatal("unsafe archive accepted")
			}
			if _, err := os.Lstat(filepath.Join(root, "outside")); !os.IsNotExist(err) {
				t.Fatalf("archive escaped: %v", err)
			}
		})
	}
}

func TestExtractInternalHardlink(t *testing.T) {
	root := t.TempDir()
	archive := filepath.Join(root, "pkg.tar.gz")
	if err := os.WriteFile(archive, archiveTarGz(t, "pkg",
		archiveEntry{name: "bin/tool", body: "tool"},
		archiveEntry{name: "bin/alias", typeflag: tar.TypeLink, linkname: "pkg/bin/tool"},
	), 0o600); err != nil {
		t.Fatal(err)
	}
	dst := filepath.Join(root, "store")
	if err := extractTarGz(archive, dst); err != nil {
		t.Fatal(err)
	}
	a, err := os.Stat(filepath.Join(dst, "bin/tool"))
	if err != nil {
		t.Fatal(err)
	}
	b, err := os.Stat(filepath.Join(dst, "bin/alias"))
	if err != nil || !os.SameFile(a, b) {
		t.Fatalf("hardlink not preserved: %v", err)
	}
}

func TestCollectRejectsDirectoryLinkCycleAndEscape(t *testing.T) {
	for _, target := range []string{".", t.TempDir()} {
		t.Run(target, func(t *testing.T) {
			store := t.TempDir()
			if err := os.Symlink(target, filepath.Join(store, "alias")); err != nil {
				t.Fatal(err)
			}
			if _, err := collectPkgFiles(store); err == nil {
				t.Fatal("unsafe directory symlink accepted")
			}
		})
	}
}

func TestCommandLifecycle(t *testing.T) {
	const arch = "linux-x86_64"
	c := startRegistry(t, arch, "alpha", "beta", "orphan")
	t.Setenv("XDG_CACHE_HOME", t.TempDir())
	prefix := filepath.Join(t.TempDir(), "prefix")
	var output, stderr bytes.Buffer
	c.output, c.stderr = &output, &stderr
	run := func(args ...string) string {
		t.Helper()
		output.Reset()
		if err := c.execute(append([]string{"--prefix", prefix, "--arch", arch}, args...)); err != nil {
			t.Fatalf("%v: %v", args, err)
		}
		if c.logCloser != nil {
			t.Fatal("command leaked its log file")
		}
		return output.String()
	}
	if got := run("search", "ALP"); got != "alpha\n" {
		t.Fatalf("search=%q", got)
	}
	if got := run("list", "--all"); got != "alpha\nbeta\norphan\n" {
		t.Fatalf("list --all=%q", got)
	}
	if _, err := os.Stat(prefix); !os.IsNotExist(err) {
		t.Fatalf("remote-only commands touched prefix: %v", err)
	}
	run("install", "alpha", "orphan", "alpha")
	if got := run("install", "alpha"); !strings.Contains(got, "0 installed, 1 up-to-date") {
		t.Fatalf("repeat install=%q", got)
	}
	if got := run("install", "--force", "alpha"); !strings.Contains(got, "1 installed, 0 up-to-date") {
		t.Fatalf("force install=%q", got)
	}
	if got := run("info", "alpha"); !strings.Contains(got, "Status:  installed") || !strings.Contains(got, "(up to date)") {
		t.Fatalf("info=%q", got)
	}
	if got := run("list"); !strings.Contains(got, "NAME") || !strings.Contains(got, "alpha") {
		t.Fatalf("list=%q", got)
	}
	if got := run("outdated"); got != "All packages are up to date.\n" {
		t.Fatalf("outdated=%q", got)
	}
	run("install", "--link=false", "beta")
	run("upgrade")
	if _, err := os.Lstat(filepath.Join(prefix, "bin", "beta")); !os.IsNotExist(err) {
		t.Fatalf("upgrade changed link state: %v", err)
	}
	manifest := filepath.Join(t.TempDir(), "binman.yaml")
	body := "packages:\n  link: [alpha]\n  unlink: [beta]\nprofiles:\n  first: [alpha, beta]\n  second: [beta]\n"
	if err := os.WriteFile(manifest, []byte(body), 0o600); err != nil {
		t.Fatal(err)
	}
	run("sync", "--prune", manifest)
	if _, err := os.Stat(storePath(prefix, "orphan")); !os.IsNotExist(err) {
		t.Fatalf("prune left orphan: %v", err)
	}
	for _, profile := range []string{"first", "second"} {
		if _, err := os.Stat(filepath.Join(prefix, "profile", profile, "bin", "beta")); err != nil {
			t.Fatal(err)
		}
	}
	run("sync", manifest)
	moved := filepath.Join(t.TempDir(), "moved")
	if err := os.Rename(prefix, moved); err != nil {
		t.Fatal(err)
	}
	prefix = moved
	if _, err := os.Stat(filepath.Join(prefix, "profile", "first", "bin", "alpha")); err != nil {
		t.Fatalf("profile broken after relocation: %v", err)
	}
	run("remove", "beta")
	for _, profile := range []string{"first", "second"} {
		if _, err := os.Lstat(filepath.Join(prefix, "profile", profile, "bin", "beta")); !os.IsNotExist(err) {
			t.Fatalf("remove left profile link: %v", err)
		}
	}
	destination := t.TempDir()
	run("download", "-o", destination, "alpha")
	if _, err := os.Stat(filepath.Join(destination, "alpha", "bin", "alpha")); err != nil {
		t.Fatal(err)
	}
	if got := run("version"); !strings.Contains(got, "commit:   ") || !strings.Contains(got, "platform: ") {
		t.Fatalf("version=%q", got)
	}
	run("--verbose", "list")
	if !strings.Contains(stderr.String(), "bm invoked") {
		t.Fatal("verbose log missing")
	}
	for _, args := range [][]string{{"install"}, {"remove"}, {"download"}, {"search"}, {"list", "extra"}, {"sync", "a", "b"}, {"version", "extra"}, {"install", "../unsafe"}} {
		if err := c.execute(append([]string{"--prefix", prefix}, args...)); err == nil {
			t.Fatalf("invalid args accepted: %v", args)
		}
		if c.logCloser != nil {
			t.Fatal("failed command leaked log file")
		}
	}
}

func TestUpgradeUsesLastLayerAndRefreshesLinks(t *testing.T) {
	const arch = "linux-x86_64"
	c := startRegistry(t, arch, "tool")
	t.Setenv("XDG_CACHE_HOME", t.TempDir())
	prefix := t.TempDir()
	if err := c.installPackages([]string{"tool"}, installOpts{prefix: prefix, arch: arch, linked: true}); err != nil {
		t.Fatal(err)
	}
	before, err := readMeta(prefix, "tool")
	if err != nil {
		t.Fatal(err)
	}
	first, err := tarball.LayerFromReader(bytes.NewReader(archiveTarGz(t, "tool", archiveEntry{name: "bin/ignored", body: "ignored"})))
	if err != nil {
		t.Fatal(err)
	}
	last, err := tarball.LayerFromReader(bytes.NewReader(archiveTarGz(t, "tool", archiveEntry{name: "bin/replacement", body: "updated"})))
	if err != nil {
		t.Fatal(err)
	}
	image, err := mutate.AppendLayers(empty.Image, first, last)
	if err != nil {
		t.Fatal(err)
	}
	reference, err := name.ParseReference(c.ref("tool", arch), name.Insecure)
	if err != nil {
		t.Fatal(err)
	}
	if err := remote.Write(reference, image); err != nil {
		t.Fatal(err)
	}
	if err := c.cmdUpgrade(prefix, "", nil); err != nil {
		t.Fatal(err)
	}
	after, err := readMeta(prefix, "tool")
	if err != nil {
		t.Fatal(err)
	}
	digest, err := last.Digest()
	if err != nil {
		t.Fatal(err)
	}
	if after.Digest == before.Digest || after.Digest != digest.String() || !after.Linked {
		t.Fatalf("upgrade metadata=%+v", after)
	}
	for _, file := range []string{"tool", "ignored"} {
		if _, err := os.Lstat(filepath.Join(prefix, "bin", file)); !os.IsNotExist(err) {
			t.Fatalf("unexpected link %s: %v", file, err)
		}
	}
	if data, err := os.ReadFile(filepath.Join(prefix, "bin", "replacement")); err != nil || string(data) != "updated" {
		t.Fatalf("updated binary=%q err=%v", data, err)
	}
}

func TestIndependentRegistryClients(t *testing.T) {
	for index := range 4 {
		t.Run(fmt.Sprint(index), func(t *testing.T) {
			t.Parallel()
			name := fmt.Sprintf("package-%d", index)
			c := startRegistry(t, "linux-x86_64", name)
			names, err := c.remotePackageNames("linux-x86_64")
			if err != nil || len(names) != 1 || names[0] != name {
				t.Fatalf("registry isolation: %v %v", names, err)
			}
		})
	}
}

func TestProfileOrderAndFreshFileLists(t *testing.T) {
	c := newClient(defaultRegistry, io.Discard, io.Discard)
	prefix := t.TempDir()
	for _, name := range []string{"first", "second"} {
		path := filepath.Join(storePath(prefix, name), "bin", "tool")
		if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(path, []byte(name), 0o755); err != nil {
			t.Fatal(err)
		}
	}
	profiles := map[string][]string{"a": {"first", "second"}, "b": {"second", "first"}}
	if err := c.rebuildProfiles(prefix, profiles); err != nil {
		t.Fatal(err)
	}
	for profile, want := range map[string]string{"a": "second", "b": "first"} {
		got, err := os.ReadFile(filepath.Join(prefix, "profile", profile, "bin", "tool"))
		if err != nil || string(got) != want {
			t.Fatalf("profile %s=%q err=%v", profile, got, err)
		}
	}
	if err := os.Remove(filepath.Join(storePath(prefix, "first"), "bin", "tool")); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(storePath(prefix, "first"), "bin", "new"), []byte("new"), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := c.rebuildProfiles(prefix, profiles); err != nil {
		t.Fatal(err)
	}
	for profile := range profiles {
		if _, err := os.Stat(filepath.Join(prefix, "profile", profile, "bin", "new")); err != nil {
			t.Fatal(err)
		}
	}
}

func TestLinkKeepsCorrectSymlink(t *testing.T) {
	prefix := t.TempDir()
	path := filepath.Join(storePath(prefix, "pkg"), "bin", "tool")
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(path, []byte("tool"), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := linkPkg(prefix, "pkg"); err != nil {
		t.Fatal(err)
	}
	link := filepath.Join(prefix, "bin", "tool")
	before, err := os.Lstat(link)
	if err != nil {
		t.Fatal(err)
	}
	if err := linkPkg(prefix, "pkg"); err != nil {
		t.Fatal(err)
	}
	after, err := os.Lstat(link)
	if err != nil || !os.SameFile(before, after) {
		t.Fatalf("correct symlink replaced: %v", err)
	}
}

type failingReader struct{}

func (failingReader) Read([]byte) (int, error) { return 0, io.ErrUnexpectedEOF }

func TestWriteAtomicPreservesExistingOnFailure(t *testing.T) {
	path := filepath.Join(t.TempDir(), "cache.tar.gz")
	if err := os.WriteFile(path, []byte("original"), 0o600); err != nil {
		t.Fatal(err)
	}
	if err := writeAtomic(path, 0o600, io.MultiReader(strings.NewReader("partial"), failingReader{})); err == nil {
		t.Fatal("expected write failure")
	}
	data, err := os.ReadFile(path)
	if err != nil || !bytes.Equal(data, []byte("original")) {
		t.Fatalf("cache changed: %q %v", data, err)
	}
	entries, err := os.ReadDir(filepath.Dir(path))
	if err != nil || len(entries) != 1 {
		t.Fatalf("temporary cache file remains: %v %v", entries, err)
	}
}
