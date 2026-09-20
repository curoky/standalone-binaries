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
	if len(os.Args) > 1 && os.Args[1] == "--remote" {
		if os.Args[2] != "--url=unix:///run/podman/podman.sock" {
			return fmt.Errorf("wrong client endpoint: %v", os.Args)
		}
		return nil
	}
	// The registry reader consumes this environment variable while loading the
	// configuration, including indirectly through config.New. Keep the wrapper's
	// original value and restore it before each independent reader check.
	registryPath := os.Getenv("CONTAINERS_REGISTRIES_CONF")
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
	for _, ctx := range []*types.SystemContext{nil, {SystemRegistriesConfPath: registryPath}} {
		if err := os.Setenv("CONTAINERS_REGISTRIES_CONF", registryPath); err != nil {
			return err
		}
		regs, err := sysregistriesv2.UnqualifiedSearchRegistries(ctx)
		if err != nil {
			return err
		}
		if len(regs) != 1 || regs[0] != "docker.io" {
			return fmt.Errorf("unexpected registry search from %s with CONTAINERS_REGISTRIES_CONF=%q: %v", sysregistriesv2.ConfigurationSourceDescription(ctx), registryPath, regs)
		}
		if dir := sysregistriesv2.ConfigDirPath(ctx); dir != "" {
			return fmt.Errorf("registry drop-ins still active: %s", dir)
		}
	}
	if len(os.Args) > 1 {
		if err := os.Setenv("CONTAINERS_REGISTRIES_CONF", registryPath); err != nil {
			return err
		}
		root := filepath.Dir(os.Getenv("PODMAN_DATA_DIR"))
		if os.Getenv("SSL_CERT_FILE") != filepath.Join(root, "conf/ca-bundle.crt") || os.Getenv("SSL_CERT_DIR") != filepath.Join(root, "conf/certs") {
			return fmt.Errorf("TLS trust escaped bundle")
		}
	}
	if cfg.Network.FirewallDriver != "nftables" || cfg.Network.DNSBindPort != 53 || cfg.Engine.OCIRuntime != "crun" || cfg.Engine.DBBackend != "sqlite" || cfg.Engine.CgroupManager != "cgroupfs" {
		return fmt.Errorf("unexpected backend: %+v, %+v", cfg.Network, cfg.Engine)
	}
	if helpers := cfg.Engine.HelperBinariesDir.Get(); len(helpers) != 1 || helpers[0] != "$BINDIR/../libexec/podman" {
		return fmt.Errorf("unexpected helper directories: %v", helpers)
	}
	if len(cfg.Engine.ConmonPath.Get()) != 0 || len(cfg.Engine.OCIRuntimes["crun"]) != 0 || len(cfg.Engine.OCIRuntimes["runc"]) != 0 {
		return fmt.Errorf("unexpected conmon or OCI runtime paths")
	}
	if cfg.Engine.CompressionFormat != "zstd:chunked" || cfg.Engine.CompressionLevel == nil || *cfg.Engine.CompressionLevel != 3 {
		return fmt.Errorf("unexpected compression")
	}
	data := os.Getenv("PODMAN_DATA_DIR")
	runtime := os.Getenv("PODMAN_RUNTIME_DIR")
	if runtime == "" {
		return fmt.Errorf("missing Podman runtime directory")
	}
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
	if opts.GraphDriverName != "overlay" || opts.GraphRoot != filepath.Join(data, "graphroot") || opts.RunRoot != filepath.Join(runtime, "storage") {
		return fmt.Errorf("unexpected storage: %+v", opts)
	}
	root := filepath.Dir(data)
	for _, name := range []string{"conmon", "crun", "runc", "pasta", "catatonit", "netavark", "aardvark-dns"} {
		var path string
		switch name {
		case "conmon":
			path, err = cfg.FindConmon()
		case "catatonit":
			path, err = cfg.FindInitBinary()
		default:
			path, err = cfg.FindHelperBinary(name, true)
		}
		if err != nil || path != filepath.Join(root, "libexec/podman", name) {
			return fmt.Errorf("unexpected %s path %q: %w", name, path, err)
		}
	}
	if len(os.Args) > 1 && os.Args[1] != "--network-config-dir="+filepath.Join(root, "conf/networks") {
		return fmt.Errorf("wrong network configuration directory: %v", os.Args)
	}
	if len(os.Args) > 2 && os.Args[2] != "--tmpdir="+filepath.Join(runtime, "libpod") {
		return fmt.Errorf("wrong libpod temporary directory: %v", os.Args)
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
