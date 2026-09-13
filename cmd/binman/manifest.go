package main

import (
	"fmt"
	"io"
	"maps"
	"os"
	"path/filepath"
	"slices"

	"gopkg.in/yaml.v3"
)

const defaultManifest = "binman.yaml"

type manifest struct {
	Prefix   string              `yaml:"prefix"`
	Arch     string              `yaml:"arch"`
	Packages packageSet          `yaml:"packages"`
	Profiles map[string][]string `yaml:"profiles"`
}

type packageSet struct {
	Link   []string `yaml:"link"`
	Unlink []string `yaml:"unlink"`
}

type syncOpts struct {
	prefix, arch       string
	prefixSet, archSet bool
	force, prune       bool
}

func loadManifest(path string) (manifest, error) {
	var config manifest
	file, err := os.Open(path)
	if err != nil {
		return config, err
	}
	defer file.Close()
	decoder := yaml.NewDecoder(file)
	decoder.KnownFields(true)
	if err := decoder.Decode(&config); err != nil {
		return config, fmt.Errorf("%s: %w", path, err)
	}
	var extra any
	if err := decoder.Decode(&extra); err != io.EOF {
		if err == nil {
			return config, fmt.Errorf("%s: multiple YAML documents are not supported", path)
		}
		return config, fmt.Errorf("%s: %w", path, err)
	}
	if config.Arch != "" {
		if err := validateArch(config.Arch); err != nil {
			return config, fmt.Errorf("%s: %w", path, err)
		}
	}
	count := 0
	for _, packages := range [][]string{config.Packages.Link, config.Packages.Unlink} {
		for _, packageName := range packages {
			if err := validatePackageName(packageName); err != nil {
				return config, fmt.Errorf("%s: %w", path, err)
			}
			count++
		}
	}
	for profile, packages := range config.Profiles {
		if err := validateProfileName(profile); err != nil {
			return config, fmt.Errorf("%s: %w", path, err)
		}
		for _, packageName := range packages {
			if err := validatePackageName(packageName); err != nil {
				return config, fmt.Errorf("%s: profile %s: %w", path, profile, err)
			}
			count++
		}
	}
	if count == 0 {
		return config, fmt.Errorf("%s: no packages listed", path)
	}
	return config, nil
}

// Root links take precedence when a package appears in multiple sections.
func (config manifest) installPlan() []installTarget {
	var plan []installTarget
	seen := make(map[string]bool)
	add := func(packages []string, linked bool) {
		for _, packageName := range packages {
			if !seen[packageName] {
				seen[packageName] = true
				plan = append(plan, installTarget{name: packageName, linked: linked})
			}
		}
	}
	add(config.Packages.Link, true)
	add(config.Packages.Unlink, false)
	for _, profile := range sortedProfileNames(config.Profiles) {
		add(config.Profiles[profile], false)
	}
	return plan
}

func (c *client) cmdSync(file string, options syncOpts) error {
	config, err := loadManifest(file)
	if err != nil {
		return err
	}
	prefix, arch := options.prefix, options.arch
	if !options.archSet && config.Arch != "" {
		arch = config.Arch
	}
	if !options.prefixSet && config.Prefix != "" {
		prefix = config.Prefix
	}
	plan := config.installPlan()
	c.logger.Info("sync started", "file", file, "prefix", prefix, "link", config.Packages.Link,
		"unlink", config.Packages.Unlink, "profiles", len(config.Profiles), "prune", options.prune)
	fmt.Fprintf(c.output, "> Syncing %d unique package(s) from %s...\n", len(plan), file)
	if err := c.installPackagePlan(plan, prefix, arch, options.force); err != nil {
		return err
	}
	if err := c.rebuildProfiles(prefix, config.Profiles); err != nil {
		return err
	}
	if !options.prune {
		return nil
	}
	wanted := make(map[string]bool, len(plan))
	for _, target := range plan {
		wanted[target.name] = true
	}
	installed, err := installedNames(prefix)
	if err != nil {
		return err
	}
	for _, packageName := range installed {
		if !wanted[packageName] {
			c.logger.Info("prune removing package not in manifest", "package", packageName)
			if err := c.cmdRemove(prefix, packageName); err != nil {
				return err
			}
		}
	}
	return nil
}

func (c *client) rebuildProfiles(prefix string, profiles map[string][]string) error {
	profileParent := filepath.Join(prefix, "profile")
	if err := os.MkdirAll(prefix, 0o755); err != nil {
		return err
	}
	if err := os.RemoveAll(profileParent); err != nil {
		return fmt.Errorf("reset profiles: %w", err)
	}
	files := make(packageFiles)
	for _, profile := range sortedProfileNames(profiles) {
		root := filepath.Join(profileParent, profile)
		fmt.Fprintf(c.output, "> Linking profile %s -> %s\n", profile, root)
		for _, packageName := range profiles[profile] {
			c.logger.Info("profile link", "profile", profile, "package", packageName, "root", root)
			entries, err := files.get(storePath(prefix, packageName))
			if err != nil {
				return fmt.Errorf("profile %s: %s: %w", profile, packageName, err)
			}
			if err := linkFilesInto(entries, root); err != nil {
				return fmt.Errorf("profile %s: %s: %w", profile, packageName, err)
			}
		}
	}
	return nil
}

func sortedProfileNames(profiles map[string][]string) []string {
	return slices.Sorted(maps.Keys(profiles))
}
