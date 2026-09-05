// Command bm installs standalone binaries published as OCI artifacts.
package main

import (
	"fmt"
	"io"
	"log/slog"
	"os"
	"path/filepath"
	"regexp"
	"runtime"

	"github.com/spf13/cobra"
)

const (
	defaultRegistry = "ghcr.io/curoky/standalone-binaries"
	metaFile        = ".binman-meta"
	defaultPrefix   = "/opt/bm"
	logFile         = "binman.log"
	maxParallel     = 16
)

// Build metadata is injected at link time via -ldflags "-X main.<var>=...".
var (
	buildCommit     = "unknown"
	buildCommitDate = "unknown"
	buildDate       = "unknown"
	buildHost       = "unknown"
)

var validName = regexp.MustCompile(`^[A-Za-z0-9][A-Za-z0-9._-]*$`)

type client struct {
	registry  string
	output    io.Writer
	stderr    io.Writer
	logger    *slog.Logger
	logCloser io.Closer
}

func newClient(registry string, output, stderr io.Writer) *client {
	return &client{
		registry: registry, output: output, stderr: stderr,
		logger: slog.New(slog.NewTextHandler(io.Discard, nil)),
	}
}

func (c *client) setupLogger(prefix string, verbose bool) error {
	if err := os.MkdirAll(prefix, 0o755); err != nil {
		return fmt.Errorf("cannot create prefix %s: %w", prefix, err)
	}
	path := filepath.Join(prefix, logFile)
	file, err := os.OpenFile(path, os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0o644)
	if err != nil {
		return fmt.Errorf("cannot open log file %s: %w", path, err)
	}
	var writer io.Writer = file
	if verbose {
		writer = io.MultiWriter(file, c.stderr)
	}
	c.logger = slog.New(slog.NewTextHandler(writer, &slog.HandlerOptions{Level: slog.LevelDebug}))
	c.logCloser = file
	return nil
}

func detectPrefix() string {
	exe, err := os.Executable()
	if err != nil {
		return defaultPrefix
	}
	if resolved, err := filepath.EvalSymlinks(exe); err == nil {
		exe = resolved
	}
	return prefixFromExecutable(exe)
}

func prefixFromExecutable(exe string) string {
	binDir := filepath.Dir(exe)
	binmanDir := filepath.Dir(binDir)
	storeDir := filepath.Dir(binmanDir)
	if filepath.Base(binDir) == "bin" &&
		filepath.Base(binmanDir) == "binman" &&
		filepath.Base(storeDir) == "store" {
		return filepath.Dir(storeDir)
	}
	return defaultPrefix
}

func detectArch() (string, error) {
	switch {
	case runtime.GOOS == "linux" && runtime.GOARCH == "amd64":
		return "linux-x86_64", nil
	case runtime.GOOS == "linux" && runtime.GOARCH == "arm64":
		return "linux-arm64", nil
	case runtime.GOOS == "darwin" && runtime.GOARCH == "arm64":
		return "darwin-arm64", nil
	}
	return "", fmt.Errorf("unsupported platform %s/%s; pass --arch linux-x86_64, linux-arm64 or darwin-arm64",
		runtime.GOOS, runtime.GOARCH)
}

func validateArch(arch string) error {
	if arch != "linux-x86_64" && arch != "linux-arm64" && arch != "darwin-arm64" {
		return fmt.Errorf("unsupported arch %q; expected linux-x86_64, linux-arm64 or darwin-arm64", arch)
	}
	return nil
}

func validateName(kind, name string) error {
	if !validName.MatchString(name) {
		return fmt.Errorf("invalid %s name %q", kind, name)
	}
	return nil
}

func validatePackageName(name string) error { return validateName("package", name) }
func validateProfileName(name string) error { return validateName("profile", name) }

func (c *client) command() *cobra.Command {
	var prefix, arch string
	var verbose, listAll bool
	resolveArch := func() (string, error) {
		if arch != "" {
			return arch, nil
		}
		return detectArch()
	}
	withArch := func(run func(*cobra.Command, []string, string) error) func(*cobra.Command, []string) error {
		return func(cmd *cobra.Command, args []string) error {
			arch, err := resolveArch()
			if err != nil {
				return err
			}
			return run(cmd, args, arch)
		}
	}

	root := &cobra.Command{
		Use: "bm", Short: "package manager for ghcr.io/curoky/standalone-binaries",
		SilenceUsage: true, SilenceErrors: true,
		PersistentPreRunE: func(cmd *cobra.Command, args []string) error {
			if prefix == "" {
				prefix = detectPrefix()
			}
			if cmd.Name() == "download" || cmd.Name() == "search" || (cmd.Name() == "list" && listAll) {
				return nil
			}
			if err := c.setupLogger(prefix, verbose); err != nil {
				return err
			}
			c.logger.Info("bm invoked", "command", cmd.Name(), "args", args,
				"prefix", prefix, "arch", arch, "verbose", verbose)
			return nil
		},
	}
	root.SetOut(c.output)
	root.SetErr(c.stderr)
	flags := root.PersistentFlags()
	flags.StringVar(&prefix, "prefix", "", "install prefix (default: derived from bm's location, else "+defaultPrefix+")")
	flags.StringVar(&arch, "arch", "", "arch tag: linux-x86_64 | linux-arm64 | darwin-arm64 (auto-detected)")
	flags.BoolVar(&verbose, "verbose", false, "also print the detailed log to stderr")

	var linked, force bool
	install := &cobra.Command{
		Use: "install <package>...", Short: "Install/refresh one or more packages",
		Args: cobra.MinimumNArgs(1),
		RunE: withArch(func(cmd *cobra.Command, args []string, arch string) error {
			return c.installPackages(args, installOpts{prefix: prefix, arch: arch, linked: linked, force: force})
		}),
	}
	install.Flags().BoolVar(&linked, "link", true, "expose binaries via relative symlinks")
	install.Flags().BoolVar(&force, "force", false, "reinstall even if the digest already matches")

	var destination string
	download := &cobra.Command{
		Use: "download <package>...", Short: "Download and extract packages without installing them",
		Args: cobra.MinimumNArgs(1),
		RunE: withArch(func(cmd *cobra.Command, args []string, arch string) error {
			return c.downloadPackages(args, arch, destination)
		}),
	}
	download.Flags().StringVarP(&destination, "output", "o", ".", "directory to extract packages into")

	remove := &cobra.Command{
		Use: "remove <package>", Short: "Uninstall a package and clean up its links",
		Args: cobra.ExactArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error { return c.cmdRemove(prefix, args[0]) },
	}
	upgrade := &cobra.Command{
		Use: "upgrade [package...]", Short: "Upgrade the given packages, or all installed packages if none is given",
		RunE: func(cmd *cobra.Command, args []string) error {
			overrideArch := ""
			if cmd.Flags().Changed("arch") {
				overrideArch = arch
			}
			return c.cmdUpgrade(prefix, overrideArch, args)
		},
	}
	info := &cobra.Command{
		Use: "info <package>", Short: "Show a package's metadata and whether it is up to date",
		Args: cobra.ExactArgs(1),
		RunE: withArch(func(cmd *cobra.Command, args []string, arch string) error {
			return c.cmdInfo(prefix, arch, args[0])
		}),
	}
	list := &cobra.Command{
		Use: "list", Short: "List installed packages, or all available packages with --all",
		Args: cobra.NoArgs,
		RunE: func(cmd *cobra.Command, args []string) error {
			if !listAll {
				return c.cmdList(prefix)
			}
			arch, err := resolveArch()
			if err != nil {
				return err
			}
			return c.cmdListAvailable(arch)
		},
	}
	list.Flags().BoolVarP(&listAll, "all", "a", false, "list all packages available for the selected architecture")
	search := &cobra.Command{
		Use: "search <query>", Short: "Search all packages available for the selected architecture",
		Args: cobra.ExactArgs(1),
		RunE: withArch(func(cmd *cobra.Command, args []string, arch string) error {
			return c.cmdSearch(arch, args[0])
		}),
	}
	outdated := &cobra.Command{
		Use: "outdated", Short: "Show installed packages whose remote digest has changed",
		Args: cobra.NoArgs,
		RunE: func(cmd *cobra.Command, args []string) error { return c.cmdOutdated(prefix) },
	}
	version := &cobra.Command{
		Use: "version", Short: "Show build metadata bundled into this bm binary",
		Args: cobra.NoArgs,
		RunE: func(cmd *cobra.Command, args []string) error {
			fmt.Fprintf(c.output, "commit:   %s\ncommitted at: %s\nbuilt at: %s\nbuilt on: %s\ngo:       %s\nplatform: %s/%s\n",
				buildCommit, buildCommitDate, buildDate, buildHost, runtime.Version(), runtime.GOOS, runtime.GOARCH)
			return nil
		},
	}

	var syncForce, prune bool
	sync := &cobra.Command{
		Use: "sync [file]", Short: "Install packages declared in a YAML manifest (default: binman.yaml)",
		Args: cobra.MaximumNArgs(1),
		RunE: withArch(func(cmd *cobra.Command, args []string, arch string) error {
			file := defaultManifest
			if len(args) == 1 {
				file = args[0]
			}
			return c.cmdSync(file, syncOpts{
				prefix: prefix, arch: arch, force: syncForce, prune: prune,
				prefixSet: cmd.Flags().Changed("prefix"), archSet: cmd.Flags().Changed("arch"),
			})
		}),
	}
	sync.Flags().BoolVar(&syncForce, "force", false, "reinstall even if the digest already matches")
	sync.Flags().BoolVar(&prune, "prune", false, "remove installed packages not listed in the manifest")
	root.AddCommand(install, download, remove, upgrade, info, list, search, outdated, sync, version)
	return root
}

func (c *client) execute(args []string) error {
	defer func() {
		if c.logCloser != nil {
			// Logging must not replace the command's result.
			_ = c.logCloser.Close()
			c.logCloser = nil
			c.logger = slog.New(slog.NewTextHandler(io.Discard, nil))
		}
	}()
	command := c.command()
	command.SetArgs(args)
	return command.Execute()
}

func main() {
	c := newClient(defaultRegistry, os.Stdout, os.Stderr)
	if err := c.execute(os.Args[1:]); err != nil {
		fmt.Fprintln(os.Stderr, "Error:", err)
		os.Exit(1)
	}
}
