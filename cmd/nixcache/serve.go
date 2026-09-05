package main

import (
	"context"
	"fmt"
	"io"
	"log"
	"maps"
	"net"
	"net/http"
	"slices"
	"strconv"
	"strings"
	"sync"
	"sync/atomic"
	"time"

	"github.com/felixge/httpsnoop"
)

const (
	defaultHost   = "127.0.0.1"
	defaultPort   = 37515
	refreshEvery  = 5 * time.Minute
	nixCacheInfo  = "StoreDir: /nix/store\nWantMassQuery: 1\nPriority: 30\n"
	narInfoSuffix = ".narinfo"
)

type serveConfig struct {
	host string
	port int
}

func (config serveConfig) listen() (net.Listener, error) {
	if config.port < 0 || config.port > 65535 {
		return nil, fmt.Errorf("port must be between 0 and 65535, got %d", config.port)
	}
	address := net.JoinHostPort(config.host, strconv.Itoa(config.port))
	listener, err := net.Listen("tcp", address)
	if err != nil {
		return nil, fmt.Errorf("listen on %s: %w", address, err)
	}
	return listener, nil
}

type narBlob struct {
	digest string
	size   int64
}

type indexSnapshot struct {
	entries   map[string]string
	nars      map[string]narBlob
	snapshots int
}

type cacheIndex struct {
	client *registryClient
	system string

	refreshMu sync.Mutex
	segments  map[string]segmentRef
	current   atomic.Pointer[indexSnapshot]
}

func newCacheIndex(client *registryClient, system string) *cacheIndex {
	return &cacheIndex{client: client, system: system, segments: make(map[string]segmentRef)}
}

func (index *cacheIndex) refresh(ctx context.Context) (int, error) {
	index.refreshMu.Lock()
	defer index.refreshMu.Unlock()

	started := time.Now()
	tags, err := index.client.listTags(ctx, index.system)
	if err != nil {
		return 0, err
	}
	segments := make(map[string]segmentRef, len(tags))
	var missing []string
	for _, tag := range tags {
		if ref, ok := index.segments[tag]; ok {
			segments[tag] = ref
		} else {
			missing = append(missing, tag)
		}
	}
	reused := len(segments)
	removed := len(index.segments) - reused
	loaded, err := index.client.fetchSegments(ctx, missing)
	if err != nil {
		return 0, err
	}
	for _, ref := range loaded {
		if ref.System != index.system {
			return 0, fmt.Errorf("segment %s has system %q, want %q", ref.Tag, ref.System, index.system)
		}
		segments[ref.Tag] = ref
	}

	current := index.current.Load()
	if current == nil || len(loaded) != 0 || removed != 0 {
		current, err = mergeSegments(segments)
		if err != nil {
			return 0, err
		}
		index.segments = segments
		index.current.Store(current)
	}
	log.Printf("cache index refreshed: %d entries across %d snapshots; segments reused=%d loaded=%d removed=%d in %s",
		len(current.entries), current.snapshots, reused, len(loaded), removed, time.Since(started).Round(time.Millisecond))
	return len(current.entries), nil
}

func mergeSegments(segments map[string]segmentRef) (*indexSnapshot, error) {
	current := &indexSnapshot{entries: make(map[string]string), nars: make(map[string]narBlob)}
	snapshots := make(map[string]struct{})
	for _, ref := range slices.SortedFunc(maps.Values(segments), compareSegments) {
		snapshots[ref.Snapshot] = struct{}{}
		for hash, entry := range ref.Entries {
			blob := narBlob{digest: entry.NARDigest, size: entry.NARSize}
			if previous, ok := current.nars[entry.NARURL]; ok && previous != blob {
				return nil, fmt.Errorf("conflicting NAR URL %s", entry.NARURL)
			}
			current.entries[hash] = entry.NARInfo
			current.nars[entry.NARURL] = blob
		}
	}
	current.snapshots = len(snapshots)
	return current, nil
}

func (index *cacheIndex) serveHTTP(writer http.ResponseWriter, request *http.Request) {
	if request.Method != http.MethodGet && request.Method != http.MethodHead {
		http.Error(writer, "method not allowed", http.StatusMethodNotAllowed)
		return
	}

	current := index.current.Load()
	path := strings.TrimPrefix(request.URL.Path, "/")
	switch {
	case path == "nix-cache-info":
		if current == nil {
			http.Error(writer, "cache index not ready", http.StatusServiceUnavailable)
			return
		}
		serveBytes(writer, request, "text/x-nix-cache-info", nixCacheInfo)
	case strings.HasSuffix(path, narInfoSuffix):
		hash := strings.TrimSuffix(path, narInfoSuffix)
		if current == nil {
			http.NotFound(writer, request)
			return
		}
		info, ok := current.entries[hash]
		if !ok {
			log.Printf("narinfo miss: %s (index has %d entries)", hash, len(current.entries))
			http.NotFound(writer, request)
			return
		}
		serveBytes(writer, request, "text/x-nix-narinfo", info)
	case strings.HasPrefix(path, "nar/"):
		if current == nil {
			http.NotFound(writer, request)
			return
		}
		blob, ok := current.nars[path]
		if !ok {
			http.NotFound(writer, request)
			return
		}
		if request.Method == http.MethodHead {
			setNARHeaders(writer, blob)
			writer.WriteHeader(http.StatusOK)
			return
		}
		reader, err := index.client.blobReader(request.Context(), blob.digest)
		if err != nil {
			log.Printf("read cache blob %s: %v", blob.digest, err)
			http.Error(writer, "read cache blob", http.StatusBadGateway)
			return
		}
		defer func() { _ = reader.Close() }() // The response is committed before stream cleanup.
		setNARHeaders(writer, blob)
		if _, err := io.Copy(writer, reader); err != nil {
			log.Printf("stream %s: %v", path, err)
		}
	default:
		http.NotFound(writer, request)
	}
}

func serveBytes(writer http.ResponseWriter, request *http.Request, contentType, body string) {
	writer.Header().Set("Content-Type", contentType)
	http.ServeContent(writer, request, "", time.Time{}, strings.NewReader(body))
}

func setNARHeaders(writer http.ResponseWriter, blob narBlob) {
	writer.Header().Set("Content-Type", "application/x-nix-nar")
	writer.Header().Set("Content-Length", strconv.FormatInt(blob.size, 10))
	writer.Header().Set("ETag", `"`+blob.digest+`"`)
}

func serveCache(ctx context.Context, client *registryClient, system string, config serveConfig) error {
	index := newCacheIndex(client, system)
	// Listen before loading so readiness reports 503 instead of refusing connections.
	listener, err := config.listen()
	if err != nil {
		return err
	}

	server := &http.Server{
		Handler:           withAccessLog(http.HandlerFunc(index.serveHTTP)),
		ReadHeaderTimeout: 10 * time.Second,
		IdleTimeout:       2 * time.Minute,
	}
	serveErr := make(chan error, 1)
	go func() { serveErr <- server.Serve(listener) }()
	log.Printf("serving Nix cache at http://%s", listener.Addr())

	if _, err := index.refresh(ctx); err != nil {
		_ = server.Close()
		return fmt.Errorf("load initial cache index: %w", err)
	}

	go func() {
		ticker := time.NewTicker(refreshEvery)
		defer ticker.Stop()
		for {
			select {
			case <-ctx.Done():
				return
			case <-ticker.C:
				if _, err := index.refresh(ctx); err != nil {
					log.Printf("refresh cache index: %v", err)
				}
			}
		}
	}()

	return <-serveErr
}

func withAccessLog(next http.Handler) http.Handler {
	return http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		metrics := httpsnoop.CaptureMetrics(next, writer, request)
		log.Printf("%s %s -> %d (%s)", request.Method, request.URL.Path, metrics.Code, metrics.Duration.Round(time.Millisecond))
	})
}
