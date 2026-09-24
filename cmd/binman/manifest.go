package main

import (
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"

	"gopkg.in/yaml.v3"
)

type manifest struct {
	Prefix   string         `yaml:"prefix"`
	Installs []installGroup `yaml:"installs"`
}

type installGroup struct {
	Packages []string `yaml:"packages"`
	LinkTo   string   `yaml:"link-to"`
}

type installPlan struct {
	Packages []string
	LinkTo   map[string][]string
	Links    []linkOperation
}

type linkOperation struct {
	Package string
	Root    string
}

func loadManifest(filename string) (manifest, error) {
	var config manifest
	file, err := os.Open(filename)
	if err != nil {
		return config, err
	}
	defer file.Close()

	decoder := yaml.NewDecoder(file)
	decoder.KnownFields(true)
	if err := decoder.Decode(&config); err != nil {
		return config, fmt.Errorf("%s: %w", filename, err)
	}
	var extra any
	if err := decoder.Decode(&extra); err != io.EOF {
		if err == nil {
			return config, fmt.Errorf("%s: multiple YAML documents are not supported", filename)
		}
		return config, fmt.Errorf("%s: %w", filename, err)
	}
	return config, nil
}

func (config manifest) plan() (installPlan, error) {
	plan := installPlan{LinkTo: make(map[string][]string)}
	seenPackages := make(map[string]bool)
	seenLinks := make(map[linkOperation]bool)
	for groupIndex, group := range config.Installs {
		if len(group.Packages) == 0 {
			return plan, fmt.Errorf("installs[%d]: packages must not be empty", groupIndex)
		}
		root, err := cleanLinkTo(group.LinkTo)
		if err != nil {
			return plan, fmt.Errorf("installs[%d]: %w", groupIndex, err)
		}
		for _, packageName := range group.Packages {
			if err := validatePackageName(packageName); err != nil {
				return plan, fmt.Errorf("installs[%d]: %w", groupIndex, err)
			}
			if !seenPackages[packageName] {
				seenPackages[packageName] = true
				plan.Packages = append(plan.Packages, packageName)
			}
			if root == "" {
				continue
			}
			op := linkOperation{Package: packageName, Root: root}
			if seenLinks[op] {
				continue
			}
			seenLinks[op] = true
			plan.LinkTo[packageName] = append(plan.LinkTo[packageName], root)
			plan.Links = append(plan.Links, op)
		}
	}
	if len(plan.Packages) == 0 {
		return plan, fmt.Errorf("no packages listed")
	}
	return plan, nil
}
func cleanLinkTo(value string) (string, error) {
	if value == "" {
		return "", nil
	}
	if filepath.IsAbs(value) {
		return "", fmt.Errorf("link-to %q must be relative to the prefix", value)
	}
	clean := filepath.Clean(value)
	if clean == ".." || strings.HasPrefix(clean, ".."+string(os.PathSeparator)) {
		return "", fmt.Errorf("link-to %q escapes the prefix", value)
	}
	if clean == "store" || strings.HasPrefix(clean, "store"+string(os.PathSeparator)) {
		return "", fmt.Errorf("link-to %q overlaps binman's internal directory", value)
	}
	return clean, nil
}
