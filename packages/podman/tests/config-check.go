package main

import (
	"fmt"
	"os"
	"path/filepath"

	"go.podman.io/common/pkg/config"
	"go.podman.io/common/pkg/seccomp"
	"go.podman.io/image/v5/pkg/sysregistriesv2"
	"go.podman.io/image/v5/signature"
	"go.podman.io/image/v5/types"
	"go.podman.io/storage/pkg/homedir"
	storage "go.podman.io/storage/types"
)

func main() {
	if err := check(); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}

func check() error {
	cfg, err := config.New(nil)
	if err != nil {
		return err
	}
	if len(os.Args) > 1 && os.Args[1] == "helper" {
		var path string
		switch os.Args[2] {
		case "conmon":
			path, err = cfg.FindConmon()
		case "catatonit":
			path, err = cfg.FindInitBinary()
		default:
			path, err = cfg.FindHelperBinary(os.Args[2], true)
		}
		if err != nil {
			return err
		}
		fmt.Println(path)
		return nil
	}
	for _, ctx := range []*types.SystemContext{nil, {SystemRegistriesConfPath: os.Getenv("CONTAINERS_REGISTRIES_CONF")}} {
		regs, err := sysregistriesv2.UnqualifiedSearchRegistries(ctx)
		if err != nil {
			return err
		}
		if len(regs) != 1 || regs[0] != "docker.io" {
			return fmt.Errorf("unexpected registry search: %v", regs)
		}
		if dir := sysregistriesv2.ConfigDirPath(ctx); dir != "" {
			return fmt.Errorf("registry drop-ins still active: %s", dir)
		}
	}
	if len(os.Args) > 1 {
		root := filepath.Dir(os.Getenv("PODMAN_DATA_DIR"))
		if os.Getenv("SSL_CERT_FILE") != filepath.Join(root, "conf/ca-bundle.crt") || os.Getenv("SSL_CERT_DIR") != filepath.Join(root, "conf/certs") {
			return fmt.Errorf("TLS trust escaped bundle")
		}
	}
	if len(os.Args) > 1 && os.Args[1] == "--remote" {
		if os.Args[2] != "--url=unix:///run/podman/podman.sock" {
			return fmt.Errorf("wrong client endpoint: %v", os.Args)
		}
		return nil
	}
	if cfg.Network.FirewallDriver != "nftables" || cfg.Network.DNSBindPort != 53 || cfg.Engine.OCIRuntime != "crun" || cfg.Engine.DBBackend != "sqlite" || cfg.Engine.CgroupManager != "cgroupfs" {
		return fmt.Errorf("unexpected backend: %+v, %+v", cfg.Network, cfg.Engine)
	}
	if cfg.Engine.CompressionFormat != "zstd:chunked" || cfg.Engine.CompressionLevel == nil || *cfg.Engine.CompressionLevel != 3 {
		return fmt.Errorf("unexpected compression")
	}
	data := os.Getenv("PODMAN_DATA_DIR")
	if len(os.Args) > 1 {
		for suffix, get := range map[string]func() (string, error){
			".config":      homedir.GetConfigHome,
			".local/share": homedir.GetDataHome,
			".cache":       homedir.GetCacheHome,
		} {
			path, err := get()
			if err != nil {
				return err
			}
			if path != filepath.Join(data, "home", suffix) {
				return fmt.Errorf("home directory escaped bundle: %s", path)
			}
		}
	}
	opts, err := storage.DefaultStoreOptions()
	if err != nil {
		return err
	}
	if opts.GraphDriverName != "overlay" || opts.GraphRoot != filepath.Join(data, "graphroot") || opts.RunRoot != filepath.Join(data, "runroot") {
		return fmt.Errorf("unexpected storage: %+v", opts)
	}
	root := filepath.Dir(data)
	if len(os.Args) > 1 && os.Args[1] != "--network-config-dir="+filepath.Join(root, "conf/networks") {
		return fmt.Errorf("wrong network configuration directory: %v", os.Args)
	}
	if cfg.Containers.SeccompProfile != "" {
		return fmt.Errorf("unexpected external seccomp profile %s", cfg.Containers.SeccompProfile)
	}
	profile, err := seccomp.GetDefaultProfile(nil)
	if err != nil {
		return err
	}
	if profile == nil || len(profile.Syscalls) == 0 || profile.DefaultAction == "SCMP_ACT_ALLOW" {
		return fmt.Errorf("missing built-in seccomp restrictions")
	}
	if _, err := signature.DefaultPolicy(nil); err != nil {
		return err
	}
	return nil
}
