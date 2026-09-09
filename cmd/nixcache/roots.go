package main

import (
	"encoding/json"
	"fmt"
	"io"
	"log"
	"os"
	"slices"
	"strings"

	"github.com/nix-community/go-nix/pkg/narinfo"
)

type packageRoots struct {
	Out     string   `json:"out"`
	Archive string   `json:"archive"`
	Sources []string `json:"sources"`
}

type cacheRoots map[string]map[string]packageRoots

var cacheSystems = []string{"x86_64-linux", "aarch64-linux", "aarch64-darwin"}

func loadRoots(path string) (cacheRoots, error) {
	file, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	defer file.Close()
	info, err := file.Stat()
	if err != nil {
		return nil, err
	}
	if info.Size() > maxMetadataSize {
		return nil, fmt.Errorf("roots exceed metadata size limit")
	}
	var roots cacheRoots
	decoder := json.NewDecoder(io.LimitReader(file, maxMetadataSize+1))
	decoder.DisallowUnknownFields()
	if err := decoder.Decode(&roots); err != nil {
		return nil, fmt.Errorf("decode roots: %w", err)
	}
	var extra any
	if err := decoder.Decode(&extra); err != io.EOF {
		return nil, fmt.Errorf("roots must contain exactly one JSON document")
	}
	if err := roots.validate(); err != nil {
		return nil, err
	}
	return roots, nil
}

func (roots cacheRoots) validate() error {
	if len(roots) != len(cacheSystems) {
		return fmt.Errorf("roots must include all three supported systems")
	}
	for system, packages := range roots {
		if !slices.Contains(cacheSystems, system) || len(packages) == 0 {
			return fmt.Errorf("invalid or empty roots for system %q", system)
		}
		for name, paths := range packages {
			if name == "" || len(paths.Sources) == 0 {
				return fmt.Errorf("incomplete roots for %s/%s", system, name)
			}
			for _, path := range append([]string{paths.Out, paths.Archive}, paths.Sources...) {
				if _, err := storeHash(path); err != nil {
					return fmt.Errorf("root %s/%s: %w", system, name, err)
				}
			}
		}
	}
	return nil
}

func protectedSegments(segments []segmentRef, roots cacheRoots) (map[string]bool, error) {
	if err := roots.validate(); err != nil {
		return nil, err
	}
	protected := make(map[string]bool)
	type provider struct {
		ref   segmentRef
		entry cacheEntry
	}
	for system, packages := range roots {
		providers := make(map[string]provider)
		for _, ref := range segments {
			if ref.System != system {
				continue
			}
			for _, entry := range ref.Entries {
				previous, ok := providers[entry.StorePath]
				if !ok || compareSegments(previous.ref, ref) < 0 {
					providers[entry.StorePath] = provider{ref, entry}
				}
			}
		}
		var pending []string
		missing := 0
		for _, paths := range packages {
			for _, path := range append([]string{paths.Out, paths.Archive}, paths.Sources...) {
				if _, ok := providers[path]; ok {
					pending = append(pending, path)
				} else {
					missing++
				}
			}
		}
		visited := make(map[string]bool)
		for len(pending) > 0 {
			path := pending[len(pending)-1]
			pending = pending[:len(pending)-1]
			if visited[path] {
				continue
			}
			item, ok := providers[path]
			if !ok {
				return nil, fmt.Errorf("cached root closure is incomplete on %s: missing %s", system, path)
			}
			visited[path] = true
			protected[item.ref.Tag] = true
			info, err := narinfo.Parse(strings.NewReader(item.entry.NARInfo))
			if err != nil {
				return nil, err
			}
			for _, reference := range info.References {
				pending = append(pending, "/nix/store/"+reference)
			}
		}
		log.Printf("roots %s: %d packages, %d uncached roots, %d reachable paths", system, len(packages), missing, len(visited))
	}
	return protected, nil
}
