package main

import (
	"bytes"
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/opencontainers/image-spec/specs-go"
	ocispec "github.com/opencontainers/image-spec/specs-go/v1"
	"oras.land/oras-go/v2/content"
)

func TestPublicationIdentity(t *testing.T) {
	ctx := context.Background()
	client := testRegistryClient(t)
	paths := testRoots()["x86_64-linux"]["root"]
	ready, err := publicationReady(ctx, client, "root-linux-x86_64", "x86_64-linux", paths.Out, paths.Archive)
	if err != nil || ready {
		t.Fatalf("missing publication: %t %v", ready, err)
	}
	body := []byte("tarball")
	layer := content.NewDescriptorFromBytes(archiveMediaType, body)
	if err := client.repo.Blobs().Push(ctx, layer, bytes.NewReader(body)); err != nil {
		t.Fatal(err)
	}
	configBody := []byte("{}")
	config := content.NewDescriptorFromBytes(ocispec.MediaTypeImageConfig, configBody)
	if err := client.repo.Blobs().Push(ctx, config, bytes.NewReader(configBody)); err != nil {
		t.Fatal(err)
	}
	for _, test := range []struct {
		name        string
		annotations map[string]string
		want        bool
	}{
		{"missing identity", nil, false},
		{"matching", map[string]string{publicationSystem: "x86_64-linux", publicationOut: paths.Out, publicationArchive: paths.Archive}, true},
		{"old archive", map[string]string{publicationSystem: "x86_64-linux", publicationOut: paths.Out, publicationArchive: paths.Out}, false},
		{"wrong platform", map[string]string{publicationSystem: "aarch64-linux", publicationOut: paths.Out, publicationArchive: paths.Archive}, false},
	} {
		t.Run(test.name, func(t *testing.T) {
			manifest, _ := json.Marshal(ocispec.Manifest{Versioned: specs.Versioned{SchemaVersion: 2}, MediaType: ocispec.MediaTypeImageManifest, Config: config, Layers: []ocispec.Descriptor{layer}, Annotations: test.annotations})
			if err := client.repo.PushReference(ctx, content.NewDescriptorFromBytes(ocispec.MediaTypeImageManifest, manifest), bytes.NewReader(manifest), "root-linux-x86_64"); err != nil {
				t.Fatal(err)
			}
			ready, err := publicationReady(ctx, client, "root-linux-x86_64", "x86_64-linux", paths.Out, paths.Archive)
			if err != nil || ready != test.want {
				t.Fatalf("ready=%t err=%v", ready, err)
			}
		})
	}
}

func TestPublicationErrorsAreNotMisses(t *testing.T) {
	for _, status := range []int{http.StatusForbidden, http.StatusOK} {
		t.Run(http.StatusText(status), func(t *testing.T) {
			server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
				w.Header().Set("Content-Type", ocispec.MediaTypeImageManifest)
				w.WriteHeader(status)
				_, _ = w.Write([]byte("not JSON"))
			}))
			defer server.Close()
			client, err := newRegistryClient(server.Listener.Addr().String()+"/cache", true)
			if err != nil {
				t.Fatal(err)
			}
			paths := testRoots()["x86_64-linux"]["root"]
			if _, err := publicationReady(context.Background(), client, "root", "x86_64-linux", paths.Out, paths.Archive); err == nil {
				t.Fatal("protocol/auth failure reported as miss")
			}
		})
	}
}
