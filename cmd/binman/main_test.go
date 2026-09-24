package main

import (
	"archive/tar"
	"bytes"
	"compress/gzip"
	"context"
	"fmt"
	"io"
	"net/http"
	"net/http/httptest"
	"net/url"
	"os"
	"path/filepath"
	"strings"
	"sync/atomic"
	"testing"
	"time"

	"github.com/google/go-containerregistry/pkg/name"
	"github.com/google/go-containerregistry/pkg/registry"
	"github.com/google/go-containerregistry/pkg/v1/empty"
	"github.com/google/go-containerregistry/pkg/v1/mutate"
	"github.com/google/go-containerregistry/pkg/v1/remote"
	"github.com/google/go-containerregistry/pkg/v1/tarball"
	"github.com/google/go-containerregistry/pkg/v1/types"
)

type archiveEntry struct {
	Name     string
	Body     string
	LinkName string
	Type     byte
	Mode     int64
}

func archiveTarGz(t testing.TB, packageName string, entries ...archiveEntry) []byte {
	t.Helper()
	var output bytes.Buffer
	gzipWriter := gzip.NewWriter(&output)
	tarWriter := tar.NewWriter(gzipWriter)
	for _, entry := range entries {
		if entry.Type == 0 {
			entry.Type = tar.TypeReg
		}
		if entry.Mode == 0 {
			entry.Mode = 0o755
		}
		header := &tar.Header{
			Name:     "./" + packageName + "/" + entry.Name,
			Mode:     entry.Mode,
			Size:     int64(len(entry.Body)),
			Typeflag: entry.Type,
			Linkname: entry.LinkName,
		}
		if err := tarWriter.WriteHeader(header); err != nil {
			t.Fatal(err)
		}
		if entry.Body != "" {
			if _, err := tarWriter.Write([]byte(entry.Body)); err != nil {
				t.Fatal(err)
			}
		}
	}
	if err := tarWriter.Close(); err != nil {
		t.Fatal(err)
	}
	if err := gzipWriter.Close(); err != nil {
		t.Fatal(err)
	}
	return output.Bytes()
}

func packageArchive(t testing.TB, packageName, executable, body string) []byte {
	t.Helper()
	return archiveTarGz(t, packageName, archiveEntry{Name: "bin/" + executable, Body: body})
}

func testArch(t testing.TB) string {
	t.Helper()
	arch, err := detectArch()
	if err != nil {
		t.Fatal(err)
	}
	return arch
}

func startRegistry(t *testing.T, middleware func(http.Handler) http.Handler, packages map[string][]byte) *client {
	t.Helper()
	var handler http.Handler = registry.New()
	if middleware != nil {
		handler = middleware(handler)
	}
	server := httptest.NewServer(handler)
	t.Cleanup(server.Close)
	parsed, err := url.Parse(server.URL)
	if err != nil {
		t.Fatal(err)
	}
	repository := parsed.Host + "/binman"
	for packageName, archive := range packages {
		layer, err := tarball.LayerFromReader(bytes.NewReader(archive), tarball.WithMediaType(types.OCILayer))
		if err != nil {
			t.Fatal(err)
		}
		image, err := mutate.AppendLayers(empty.Image, layer)
		if err != nil {
			t.Fatal(err)
		}
		image = mutate.MediaType(image, types.OCIManifestSchema1)
		reference, err := name.ParseReference(repository+":"+packageName+"-"+testArch(t), name.Insecure)
		if err != nil {
			t.Fatal(err)
		}
		if err := remote.Write(reference, image); err != nil {
			t.Fatal(err)
		}
	}
	return newClient(repository, io.Discard, io.Discard)
}

func TestCommandSurface(t *testing.T) {
	t.Parallel()
	var output bytes.Buffer
	client := newClient(defaultRegistry, &output, &output)
	if err := client.execute(context.Background(), []string{"--help"}); err != nil {
		t.Fatal(err)
	}
	help := output.String()
	for _, command := range []string{"install", "remove"} {
		if !strings.Contains(help, command) {
			t.Fatalf("help does not contain %q:\n%s", command, help)
		}
	}
	if strings.Contains(help, "completion") {
		t.Fatalf("help exposes completion command:\n%s", help)
	}
}

func TestManifestPlan(t *testing.T) {
	t.Parallel()
	config := manifest{
		Prefix: "/opt/bm",
		Installs: []installGroup{
			{Packages: []string{"alpha", "beta"}, LinkTo: "."},
			{Packages: []string{"alpha", "gamma"}, LinkTo: "profile/go"},
			{Packages: []string{"runtime"}},
		},
	}
	plan, err := config.plan()
	if err != nil {
		t.Fatal(err)
	}
	if got, want := strings.Join(plan.Packages, ","), "alpha,beta,gamma,runtime"; got != want {
		t.Fatalf("packages=%q want %q", got, want)
	}
	if got, want := strings.Join(plan.LinkTo["alpha"], ","), ".,profile/go"; got != want {
		t.Fatalf("alpha link-to=%q want %q", got, want)
	}
	if len(plan.LinkTo["runtime"]) != 0 {
		t.Fatalf("runtime unexpectedly linked: %v", plan.LinkTo["runtime"])
	}
	var operations []string
	for _, operation := range plan.Links {
		operations = append(operations, operation.Package+"@"+operation.Root)
	}
	if got, want := strings.Join(operations, ","), "alpha@.,beta@.,alpha@profile/go,gamma@profile/go"; got != want {
		t.Fatalf("links=%q want %q", got, want)
	}
}

func TestManifestIsStrict(t *testing.T) {
	t.Parallel()
	for _, test := range []struct {
		name string
		body string
	}{
		{"unknown field", "installs: []\nunknown: true\n"},
		{"multiple documents", "installs: []\n---\ninstalls: []\n"},
		{"empty group", "installs:\n  - packages: []\n"},
		{"unsafe target", "installs:\n  - packages: [tool]\n    link-to: ../outside\n"},
		{"internal target", "installs:\n  - packages: [tool]\n    link-to: .binman/store\n"},
	} {
		t.Run(test.name, func(t *testing.T) {
			filename := filepath.Join(t.TempDir(), "binman.yaml")
			if err := os.WriteFile(filename, []byte(test.body), 0o600); err != nil {
				t.Fatal(err)
			}
			config, err := loadManifest(filename)
			if err == nil {
				_, err = config.plan()
			}
			if err == nil {
				t.Fatal("invalid manifest accepted")
			}
		})
	}
}

func TestInstallLinksAndReconcilesTargetsWithoutDownload(t *testing.T) {
	var blobRequests atomic.Int32
	middleware := func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
			if request.Method == http.MethodGet && strings.Contains(request.URL.Path, "/blobs/") {
				blobRequests.Add(1)
			}
			next.ServeHTTP(writer, request)
		})
	}
	c := startRegistry(t, middleware, map[string][]byte{
		"tool": packageArchive(t, "tool", "tool", "first"),
	})
	prefix := t.TempDir()
	plan, err := (manifest{Installs: []installGroup{{Packages: []string{"tool"}, LinkTo: "."}}}).plan()
	if err != nil {
		t.Fatal(err)
	}
	if err := c.install(context.Background(), prefix, plan); err != nil {
		t.Fatal(err)
	}
	firstDownloads := blobRequests.Load()
	if firstDownloads != 1 {
		t.Fatalf("blob requests=%d want 1", firstDownloads)
	}
	rootLink := filepath.Join(prefix, "bin", "tool")
	assertRelativeLink(t, rootLink)

	plan, err = (manifest{Installs: []installGroup{{Packages: []string{"tool"}, LinkTo: "profile/go"}}}).plan()
	if err != nil {
		t.Fatal(err)
	}
	if err := c.install(context.Background(), prefix, plan); err != nil {
		t.Fatal(err)
	}
	if blobRequests.Load() != firstDownloads {
		t.Fatal("unchanged package was downloaded again")
	}
	if _, err := os.Lstat(rootLink); !os.IsNotExist(err) {
		t.Fatalf("old link remains: %v", err)
	}
	profileLink := filepath.Join(prefix, "profile", "go", "bin", "tool")
	assertRelativeLink(t, profileLink)
	metadata, installed, err := readMetadata(prefix, "tool")
	if err != nil || !installed || strings.Join(metadata.LinkTo, ",") != "profile/go" {
		t.Fatalf("metadata=%+v installed=%t err=%v", metadata, installed, err)
	}

	if err := c.remove(prefix, []string{"tool"}); err != nil {
		t.Fatal(err)
	}
	if _, err := os.Lstat(profileLink); !os.IsNotExist(err) {
		t.Fatalf("remove left link: %v", err)
	}
	if _, err := os.Stat(storePath(prefix, "tool")); !os.IsNotExist(err) {
		t.Fatalf("remove left store: %v", err)
	}
}

func TestInstallConflictOrder(t *testing.T) {
	c := startRegistry(t, nil, map[string][]byte{
		"first":  packageArchive(t, "first", "tool", "first"),
		"second": packageArchive(t, "second", "tool", "second"),
	})
	prefix := t.TempDir()
	plan, err := (manifest{Installs: []installGroup{
		{Packages: []string{"first"}, LinkTo: "."},
		{Packages: []string{"second"}, LinkTo: "."},
	}}).plan()
	if err != nil {
		t.Fatal(err)
	}
	if err := c.install(context.Background(), prefix, plan); err != nil {
		t.Fatal(err)
	}
	content, err := os.ReadFile(filepath.Join(prefix, "bin", "tool"))
	if err != nil || string(content) != "second" {
		t.Fatalf("content=%q err=%v", content, err)
	}
}

func TestCommandMergesManifestAndCLI(t *testing.T) {
	c := startRegistry(t, nil, map[string][]byte{
		"from-file": packageArchive(t, "from-file", "from-file", "file"),
		"from-cli":  packageArchive(t, "from-cli", "from-cli", "cli"),
	})
	prefix := t.TempDir()
	filename := filepath.Join(t.TempDir(), "binman.yaml")
	body := fmt.Sprintf("prefix: %s\ninstalls:\n  - packages: [from-file]\n    link-to: profile/tools\n", prefix)
	if err := os.WriteFile(filename, []byte(body), 0o600); err != nil {
		t.Fatal(err)
	}
	if err := c.execute(context.Background(), []string{"install", "--file", filename, "from-cli"}); err != nil {
		t.Fatal(err)
	}
	assertRelativeLink(t, filepath.Join(prefix, "profile", "tools", "bin", "from-file"))
	assertRelativeLink(t, filepath.Join(prefix, "bin", "from-cli"))
}

func TestResolveFailureDoesNotChangePrefix(t *testing.T) {
	c := startRegistry(t, nil, map[string][]byte{
		"present": packageArchive(t, "present", "present", "present"),
	})
	prefix := t.TempDir()
	plan, err := (manifest{Installs: []installGroup{{Packages: []string{"present", "missing"}, LinkTo: "."}}}).plan()
	if err != nil {
		t.Fatal(err)
	}
	if err := c.install(context.Background(), prefix, plan); err == nil {
		t.Fatal("missing package accepted")
	}
	if _, err := os.Stat(storePath(prefix, "present")); !os.IsNotExist(err) {
		t.Fatalf("prefix changed after resolve failure: %v", err)
	}
}

func TestRemovePreflightsAllPackages(t *testing.T) {
	c := startRegistry(t, nil, map[string][]byte{
		"present": packageArchive(t, "present", "present", "present"),
	})
	prefix := t.TempDir()
	plan, err := (manifest{Installs: []installGroup{{Packages: []string{"present"}, LinkTo: "."}}}).plan()
	if err != nil {
		t.Fatal(err)
	}
	if err := c.install(context.Background(), prefix, plan); err != nil {
		t.Fatal(err)
	}
	if err := c.remove(prefix, []string{"present", "missing"}); err == nil {
		t.Fatal("missing package accepted")
	}
	if _, err := os.Stat(storePath(prefix, "present")); err != nil {
		t.Fatalf("installed package removed before preflight completed: %v", err)
	}
}

func TestResolveReusesTokenAndLimitsConcurrency(t *testing.T) {
	var tokenRequests, active, peak atomic.Int32
	middleware := func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
			if request.URL.Path == "/token" {
				tokenRequests.Add(1)
				writer.Header().Set("Content-Type", "application/json")
				_, _ = writer.Write([]byte(`{"token":"test-token"}`))
				return
			}
			if request.Header.Get("Authorization") != "Bearer test-token" {
				writer.Header().Set("WWW-Authenticate", `Bearer realm="http://`+request.Host+`/token",service="test-registry"`)
				http.Error(writer, "unauthorized", http.StatusUnauthorized)
				return
			}
			if request.Method == http.MethodGet && strings.Contains(request.URL.Path, "/manifests/") {
				current := active.Add(1)
				for {
					old := peak.Load()
					if current <= old || peak.CompareAndSwap(old, current) {
						break
					}
				}
				time.Sleep(30 * time.Millisecond)
				defer active.Add(-1)
			}
			next.ServeHTTP(writer, request)
		})
	}
	packages := make(map[string][]byte)
	var names []string
	for index := range resolveParallel + 3 {
		packageName := fmt.Sprintf("package-%d", index)
		names = append(names, packageName)
		packages[packageName] = packageArchive(t, packageName, packageName, packageName)
	}
	c := startRegistry(t, middleware, packages)
	tokenRequests.Store(0)
	peak.Store(0)
	if _, err := c.resolve(context.Background(), names, testArch(t)); err != nil {
		t.Fatal(err)
	}
	if got := tokenRequests.Load(); got != 1 {
		t.Fatalf("token requests=%d want 1", got)
	}
	if got := peak.Load(); got < 2 || got > resolveParallel {
		t.Fatalf("manifest concurrency=%d want 2..%d", got, resolveParallel)
	}
}

func TestBlobDownloadsUseConfiguredConcurrency(t *testing.T) {
	var active, peak atomic.Int32
	middleware := func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
			if request.Method == http.MethodGet && strings.Contains(request.URL.Path, "/blobs/") {
				current := active.Add(1)
				for {
					old := peak.Load()
					if current <= old || peak.CompareAndSwap(old, current) {
						break
					}
				}
				time.Sleep(30 * time.Millisecond)
				defer active.Add(-1)
			}
			next.ServeHTTP(writer, request)
		})
	}
	packages := make(map[string][]byte)
	groups := installGroup{}
	for index := range downloadParallel + 2 {
		packageName := fmt.Sprintf("package-%d", index)
		groups.Packages = append(groups.Packages, packageName)
		packages[packageName] = packageArchive(t, packageName, packageName, packageName)
	}
	c := startRegistry(t, middleware, packages)
	peak.Store(0)
	plan, err := (manifest{Installs: []installGroup{groups}}).plan()
	if err != nil {
		t.Fatal(err)
	}
	if err := c.install(context.Background(), t.TempDir(), plan); err != nil {
		t.Fatal(err)
	}
	if got := peak.Load(); got != downloadParallel {
		t.Fatalf("blob concurrency=%d want %d", got, downloadParallel)
	}
}

func TestExtractRejectsUnsafeArchives(t *testing.T) {
	t.Parallel()
	for _, test := range []struct {
		name        string
		archiveName string
		entry       archiveEntry
	}{
		{"wrong root", "other", archiveEntry{Name: "bin/tool", Body: "bad"}},
		{"traversal", "pkg", archiveEntry{Name: "../../outside", Body: "bad"}},
		{"reserved metadata", "pkg", archiveEntry{Name: metaFile, Body: "bad"}},
		{"escaping symlink", "pkg", archiveEntry{Name: "bin/link", Type: tar.TypeSymlink, LinkName: "../../outside"}},
		{"escaping hardlink", "pkg", archiveEntry{Name: "bin/link", Type: tar.TypeLink, LinkName: "pkg/../outside"}},
		{"special file", "pkg", archiveEntry{Name: "pipe", Type: tar.TypeFifo}},
	} {
		t.Run(test.name, func(t *testing.T) {
			root := t.TempDir()
			filename := filepath.Join(root, "archive.tar.gz")
			if err := os.WriteFile(filename, archiveTarGz(t, test.archiveName, test.entry), 0o600); err != nil {
				t.Fatal(err)
			}
			if err := extractTarGz(filename, filepath.Join(root, "out"), "pkg"); err == nil {
				t.Fatal("unsafe archive accepted")
			}
			if _, err := os.Lstat(filepath.Join(root, "outside")); !os.IsNotExist(err) {
				t.Fatalf("archive escaped: %v", err)
			}
		})
	}
}

func TestLinkRefusesExistingFilesAndSymlinkParents(t *testing.T) {
	t.Parallel()
	prefix := t.TempDir()
	store := storePath(prefix, "tool")
	if err := os.MkdirAll(filepath.Join(store, "bin"), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(store, "bin", "tool"), []byte("tool"), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := writeMetadata(store, metadata{Digest: "sha256:test", LinkTo: []string{"."}}); err != nil {
		t.Fatal(err)
	}
	if err := os.MkdirAll(filepath.Join(prefix, "bin"), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(prefix, "bin", "tool"), []byte("user"), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := linkPackage(prefix, "tool", "."); err == nil {
		t.Fatal("existing regular file was replaced")
	}
	if err := os.RemoveAll(filepath.Join(prefix, "bin")); err != nil {
		t.Fatal(err)
	}
	if err := os.Symlink(t.TempDir(), filepath.Join(prefix, "bin")); err != nil {
		t.Fatal(err)
	}
	if err := linkPackage(prefix, "tool", "."); err == nil {
		t.Fatal("symlink parent was followed")
	}
}

func TestLinkTargetDoesNotFollowSymlinkBelowPrefix(t *testing.T) {
	t.Parallel()
	prefix := t.TempDir()
	outside := t.TempDir()
	store := storePath(prefix, "tool")
	if err := os.MkdirAll(filepath.Join(store, "bin"), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(store, "bin", "tool"), []byte("tool"), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.Symlink(outside, filepath.Join(prefix, "profile")); err != nil {
		t.Fatal(err)
	}
	if err := linkPackage(prefix, "tool", "profile/go"); err == nil {
		t.Fatal("link target followed a symlink below the prefix")
	}
	if _, err := os.Lstat(filepath.Join(outside, "go")); !os.IsNotExist(err) {
		t.Fatalf("link created content outside prefix: %v", err)
	}
}

func TestPrefixLockSerializes(t *testing.T) {
	t.Parallel()
	prefix := t.TempDir()
	entered := make(chan struct{})
	release := make(chan struct{})
	done := make(chan error, 1)
	go func() {
		done <- withPrefixLock(prefix, func() error {
			close(entered)
			<-release
			return nil
		})
	}()
	<-entered
	secondEntered := make(chan struct{})
	go func() {
		done <- withPrefixLock(prefix, func() error {
			close(secondEntered)
			return nil
		})
	}()
	select {
	case <-secondEntered:
		t.Fatal("second operation entered while lock was held")
	case <-time.After(30 * time.Millisecond):
	}
	close(release)
	for range 2 {
		if err := <-done; err != nil {
			t.Fatal(err)
		}
	}
}

func TestRunParallelLimit(t *testing.T) {
	t.Parallel()
	var active, peak atomic.Int32
	if err := runParallel(12, 3, func(int) error {
		current := active.Add(1)
		for {
			old := peak.Load()
			if current <= old || peak.CompareAndSwap(old, current) {
				break
			}
		}
		time.Sleep(10 * time.Millisecond)
		active.Add(-1)
		return nil
	}); err != nil {
		t.Fatal(err)
	}
	if got := peak.Load(); got != 3 {
		t.Fatalf("peak=%d want 3", got)
	}
}

func assertRelativeLink(t testing.TB, filename string) {
	t.Helper()
	target, err := os.Readlink(filename)
	if err != nil {
		t.Fatal(err)
	}
	if filepath.IsAbs(target) {
		t.Fatalf("link target is absolute: %s", target)
	}
}
