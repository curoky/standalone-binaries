package main

import (
	"bytes"
	"compress/gzip"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"runtime"
	"strings"
	"testing"
)

func benchmarkStore(b *testing.B, deep bool) string {
	b.Helper()
	prefix := b.TempDir()
	store := storePath(prefix, "pkg")
	for dir := range 20 {
		rel := fmt.Sprintf("share/dir-%02d", dir)
		if deep {
			rel = filepath.Join(rel, "a/b/c/d/e/f")
		}
		path := filepath.Join(store, rel)
		if err := os.MkdirAll(path, 0o755); err != nil {
			b.Fatal(err)
		}
		for file := range 50 {
			if err := os.WriteFile(filepath.Join(path, fmt.Sprintf("file-%02d", file)), []byte("content"), 0o644); err != nil {
				b.Fatal(err)
			}
		}
	}
	return prefix
}

func BenchmarkCollectPkgFiles(b *testing.B) {
	for _, deep := range []bool{false, true} {
		b.Run(fmt.Sprintf("deep=%t", deep), func(b *testing.B) {
			prefix := benchmarkStore(b, deep)
			b.ReportAllocs()
			for b.Loop() {
				files, err := collectPkgFiles(storePath(prefix, "pkg"))
				if err != nil || len(files) != 1000 {
					b.Fatalf("files=%d err=%v", len(files), err)
				}
			}
		})
	}
}

func BenchmarkRelinkPackage(b *testing.B) {
	prefix := benchmarkStore(b, true)
	if err := linkPkg(prefix, "pkg"); err != nil {
		b.Fatal(err)
	}
	b.ReportAllocs()
	for b.Loop() {
		if err := linkPkg(prefix, "pkg"); err != nil {
			b.Fatal(err)
		}
	}
}

func BenchmarkProfileLinks(b *testing.B) {
	prefix := benchmarkStore(b, false)
	b.ReportAllocs()
	for b.Loop() {
		for profile := range 8 {
			root := filepath.Join(prefix, "profile", fmt.Sprint(profile))
			if err := linkPkgInto(prefix, "pkg", root); err != nil {
				b.Fatal(err)
			}
		}
	}
}

func BenchmarkRebuildProfiles(b *testing.B) {
	prefix := benchmarkStore(b, false)
	c := newClient(defaultRegistry, io.Discard, io.Discard)
	profiles := make(map[string][]string)
	for index := range 8 {
		profiles[fmt.Sprint(index)] = []string{"pkg"}
	}
	b.ReportAllocs()
	for b.Loop() {
		if err := c.rebuildProfiles(prefix, profiles); err != nil {
			b.Fatal(err)
		}
	}
}

func benchmarkArchive(b *testing.B, smallFiles bool) ([]byte, int64) {
	b.Helper()
	if smallFiles {
		entries := make([]archiveEntry, 1000)
		for i := range entries {
			entries[i] = archiveEntry{name: fmt.Sprintf("share/dir-%02d/file-%04d", i/50, i), body: strings.Repeat("package resource data\n", 50)}
		}
		return archiveTarGz(b, "pkg", entries...), 1000 * 50 * int64(len("package resource data\n"))
	}
	binary, err := os.ReadFile(filepath.Join(runtime.GOROOT(), "bin", "go"))
	if err != nil {
		b.Fatal(err)
	}
	binary = binary[:min(len(binary), 8<<20)]
	return archiveTarGz(b, "pkg", archiveEntry{name: "bin/tool", body: string(binary)}), int64(len(binary))
}

func BenchmarkGzipReader(b *testing.B) {
	for _, small := range []bool{false, true} {
		b.Run(fmt.Sprintf("small=%t", small), func(b *testing.B) {
			data, size := benchmarkArchive(b, small)
			b.Run("stdlib", func(b *testing.B) {
				b.SetBytes(size)
				b.ReportAllocs()
				for b.Loop() {
					r, err := gzip.NewReader(bytes.NewReader(data))
					if err != nil {
						b.Fatal(err)
					}
					if _, err := io.Copy(io.Discard, r); err != nil {
						b.Fatal(err)
					}
					if err := r.Close(); err != nil {
						b.Fatal(err)
					}
				}
			})
		})
	}
}

func BenchmarkExtractTarGz(b *testing.B) {
	for _, small := range []bool{false, true} {
		b.Run(fmt.Sprintf("small=%t", small), func(b *testing.B) {
			data, size := benchmarkArchive(b, small)
			archive := filepath.Join(b.TempDir(), "pkg.tar.gz")
			if err := os.WriteFile(archive, data, 0o600); err != nil {
				b.Fatal(err)
			}
			dst := b.TempDir()
			b.SetBytes(size)
			b.ReportAllocs()
			for b.Loop() {
				if err := extractTarGz(archive, dst); err != nil {
					b.Fatal(err)
				}
			}
		})
	}
}
