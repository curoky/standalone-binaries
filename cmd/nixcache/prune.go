package main

import (
	"context"
	"fmt"
	"log"
	"slices"
	"sort"
	"time"

	"github.com/opencontainers/go-digest"
	"golang.org/x/sync/errgroup"
)

// cacheSize reports the deduplicated on-registry byte size of the cache: every
// distinct layer digest referenced by any segment manifest is counted once,
// because segments share NAR blobs by digest.
func cacheSize(ctx context.Context, client *registryClient) (int64, error) {
	manifests, err := client.listManifests(ctx, "")
	if err != nil {
		return 0, err
	}
	seen := make(map[digest.Digest]int64)
	for _, ref := range manifests {
		seen[ref.Metadata.Digest] = ref.Metadata.Size
		for _, layer := range ref.NARLayers {
			seen[layer.Digest] = layer.Size
		}
	}
	var total int64
	for _, size := range seen {
		total += size
	}
	return total, nil
}

func pruneCache(ctx context.Context, client *registryClient, roots cacheRoots, keep, retainDays, packageKeep int, dryRun bool) error {
	if err := roots.validate(); err != nil {
		return err
	}
	if keep < 1 {
		return fmt.Errorf("keep must be at least 1, got %d", keep)
	}
	if retainDays < 0 {
		return fmt.Errorf("package-retain-days must not be negative, got %d", retainDays)
	}
	if packageKeep < 1 {
		return fmt.Errorf("package-keep must be at least 1, got %d", packageKeep)
	}
	segments, err := client.listSegments(ctx, "")
	if err != nil {
		return err
	}
	if len(segments) == 0 {
		log.Printf("no cache segments found")
		return nil
	}

	protected, err := protectedSegments(segments, roots)
	if err != nil {
		return err
	}
	candidates, _ := segmentsToDelete(segments, keep, retainDays, packageKeep)
	candidates = slices.DeleteFunc(candidates, func(ref segmentRef) bool { return protected[ref.Tag] })
	previous, gcTags, err := client.loadGC(ctx)
	if err != nil {
		return err
	}
	now := time.Now().UTC()
	if !now.After(previous.CreatedAt) {
		return fmt.Errorf("GC clock has not advanced beyond the latest record")
	}
	next, toDelete := gcPlan(candidates, previous, now)
	log.Printf("prune plan: root-protected=%d retained=%d waiting=%d eligible=%d", len(protected), len(segments)-len(candidates), len(candidates)-len(toDelete), len(toDelete))
	for _, ref := range candidates {
		log.Printf("candidate %s: outside roots and history retention, since %s", ref.Tag, next.Candidates[ref.Tag].Since.Format(time.RFC3339))
	}
	if dryRun {
		log.Printf("prune dry-run: would delete %d segment(s), no registry writes", len(toDelete))
		return nil
	}

	// GHCR does not support OCI manifest deletion, so map each tag to its
	// GitHub package version id and delete via the Packages REST API.
	ghcr, err := newGHCRClient(client.repo.Reference.Repository)
	if err != nil {
		return err
	}
	versionByTag, err := ghcr.versionsByTag(ctx)
	if err != nil {
		return fmt.Errorf("list package versions: %w", err)
	}

	deleted, err := executeGC(ctx, client, ghcr, next, toDelete, gcTags, versionByTag)
	if err != nil {
		return err
	}
	log.Printf("prune complete: deleted %d segment(s), retained %d", deleted, len(segments)-deleted)
	return nil
}

func executeGC(ctx context.Context, client *registryClient, ghcr versionDeleter, next gcState, toDelete []segmentRef, gcTags []string, versionByTag map[string]int64) (int, error) {
	oldRecords := make([]segmentRef, 0, len(gcTags))
	for _, tag := range gcTags {
		oldRecords = append(oldRecords, segmentRef{Tag: tag})
	}
	for _, ref := range append(slices.Clone(toDelete), oldRecords...) {
		if _, ok := versionByTag[ref.Tag]; !ok {
			return 0, fmt.Errorf("no package version found for %s", ref.Tag)
		}
	}
	for _, ref := range toDelete {
		current, err := client.repo.Resolve(ctx, ref.Tag)
		if err != nil {
			return 0, err
		}
		if current.Digest != ref.Digest {
			return 0, fmt.Errorf("segment %s changed during prune", ref.Tag)
		}
	}
	// Persist resets before deletion so a failed cleanup cannot resurrect an old grace period.
	if err := client.saveGC(ctx, next); err != nil {
		return 0, err
	}
	if _, err := deleteVersions(ctx, ghcr, oldRecords, versionByTag); err != nil {
		return 0, err
	}
	return deleteVersions(ctx, ghcr, toDelete, versionByTag)
}

func segmentsToDelete(segments []segmentRef, keep, retainDays, packageKeep int) ([]segmentRef, int) {
	kept := keptSnapshots(segments, keep)
	retainedPackageSegments := retainedSegmentsByPackage(segments, kept, retainDays, packageKeep)

	toDelete := make([]segmentRef, 0)
	var retained int
	for _, ref := range segments {
		if kept[ref.System][ref.Snapshot] &&
			(ref.PackageKey == "" || retainedPackageSegments[ref.Tag]) {
			retained++
			continue
		}
		toDelete = append(toDelete, ref)
	}
	return toDelete, retained
}

// segmentDeleteConcurrency bounds how many package versions are deleted in
// parallel. Deletions are independent REST calls; a large prune faces hundreds
// of tags and serial deletion takes minutes. Kept modest to stay clear of the
// GitHub API secondary rate limit.
const segmentDeleteConcurrency = 8

type versionDeleter interface {
	deleteVersion(context.Context, int64) error
}

func deleteVersions(ctx context.Context, ghcr versionDeleter, toDelete []segmentRef, versionByTag map[string]int64) (int, error) {
	versionIDs := make([]int64, len(toDelete))
	for index, ref := range toDelete {
		versionID, ok := versionByTag[ref.Tag]
		if !ok {
			return 0, fmt.Errorf("no package version found for segment %s", ref.Tag)
		}
		versionIDs[index] = versionID
	}

	group, groupCtx := errgroup.WithContext(ctx)
	group.SetLimit(segmentDeleteConcurrency)
	for index, ref := range toDelete {
		versionID := versionIDs[index]
		group.Go(func() error {
			if err := groupCtx.Err(); err != nil {
				return err
			}
			if err := ghcr.deleteVersion(groupCtx, versionID); err != nil {
				return fmt.Errorf("delete segment %s (version %d): %w", ref.Tag, versionID, err)
			}
			return nil
		})
	}
	if err := group.Wait(); err != nil {
		return 0, err
	}
	return len(toDelete), nil
}

// keptSnapshots returns, per system, the set of snapshot IDs to keep: the keep
// most recent snapshots ranked by their newest segment's creation time.
func keptSnapshots(segments []segmentRef, keep int) map[string]map[string]bool {
	newest := make(map[string]map[string]int64) // system -> snapshot -> newest unix nanos
	for _, ref := range segments {
		bySnapshot := newest[ref.System]
		if bySnapshot == nil {
			bySnapshot = make(map[string]int64)
			newest[ref.System] = bySnapshot
		}
		if created := ref.CreatedAt.UnixNano(); created > bySnapshot[ref.Snapshot] {
			bySnapshot[ref.Snapshot] = created
		}
	}

	kept := make(map[string]map[string]bool, len(newest))
	for system, bySnapshot := range newest {
		type snapshotAge struct {
			id      string
			created int64
		}
		ranked := make([]snapshotAge, 0, len(bySnapshot))
		for id, created := range bySnapshot {
			ranked = append(ranked, snapshotAge{id: id, created: created})
		}
		sort.Slice(ranked, func(i, j int) bool {
			return ranked[i].created > ranked[j].created
		})
		set := make(map[string]bool)
		for i := 0; i < len(ranked) && i < keep; i++ {
			set[ranked[i].id] = true
		}
		kept[system] = set
	}
	return kept
}

// retainedSegmentsByPackage selects, per (system, snapshot, packageKey) group in
// kept snapshots, the segments to keep: every segment whose CreatedAt falls
// within retainDays of the group's newest segment, and at least packageKeep
// segments (newest first) when the window holds fewer. Groups are ranked by
// CreatedAt with the tag string as a deterministic tie-breaker.
func retainedSegmentsByPackage(segments []segmentRef, keptSnapshots map[string]map[string]bool, retainDays, packageKeep int) map[string]bool {
	type packageIdentity struct {
		system, snapshot, packageKey string
	}
	groups := make(map[packageIdentity][]segmentRef)
	for _, ref := range segments {
		if ref.PackageKey == "" || !keptSnapshots[ref.System][ref.Snapshot] {
			continue
		}
		key := packageIdentity{ref.System, ref.Snapshot, ref.PackageKey}
		groups[key] = append(groups[key], ref)
	}

	window := time.Duration(retainDays) * 24 * time.Hour
	kept := make(map[string]bool)
	for _, group := range groups {
		sort.Slice(group, func(i, j int) bool {
			if !group[i].CreatedAt.Equal(group[j].CreatedAt) {
				return group[i].CreatedAt.After(group[j].CreatedAt)
			}
			return group[i].Tag > group[j].Tag
		})
		newest := group[0].CreatedAt
		cutoff := newest.Add(-window)
		for index, ref := range group {
			if ref.CreatedAt.After(cutoff) || index < packageKeep {
				kept[ref.Tag] = true
			}
		}
	}
	return kept
}

func shortSnapshot(id string) string {
	trimmed := id
	if len(trimmed) > 23 { // "sha256:" + 16
		trimmed = trimmed[:23]
	}
	return trimmed
}

// humanSize renders a byte count using binary units for log output.
func humanSize(bytes int64) string {
	const unit = 1024
	if bytes < unit {
		return fmt.Sprintf("%d B", bytes)
	}
	div, exp := int64(unit), 0
	for n := bytes / unit; n >= unit; n /= unit {
		div *= unit
		exp++
	}
	return fmt.Sprintf("%.2f %ciB", float64(bytes)/float64(div), "KMGTPE"[exp])
}
