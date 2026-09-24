// Command bm installs standalone packages published as OCI artifacts.
package main

import (
	"context"
	"fmt"
	"io"
	"os"
	"os/signal"
	"path/filepath"
	"regexp"
	"runtime"
	"syscall"

	"github.com/spf13/cobra"
)

const (
	defaultRegistry  = "ghcr.io/curoky/standalone-binaries"
	metaFile         = ".binman-meta"
	resolveParallel  = 4
	downloadParallel = 16
)

var validName = regexp.MustCompile(`^[A-Za-z0-9][A-Za-z0-9._-]*$`)

type client struct {
	registry string
	output   io.Writer
	stderr   io.Writer
}

func newClient(registry string, output, stderr io.Writer) *client {
	return &client{registry: registry, output: output, stderr: stderr}
}

func defaultPrefix() (string, error) {
	home, err := os.UserHomeDir()
	if err != nil {
		return "", fmt.Errorf("find home directory: %w", err)
	}
	return filepath.Join(home, ".local"), nil
}

func detectArch() (string, error) {
	switch {
	case runtime.GOOS == "linux" && runtime.GOARCH == "amd64":
		return "linux-x86_64", nil
	case runtime.GOOS == "linux" && runtime.GOARCH == "arm64":
		return "linux-arm64", nil
	case runtime.GOOS == "darwin" && runtime.GOARCH == "arm64":
		return "darwin-arm64", nil
	default:
		return "", fmt.Errorf("unsupported platform %s/%s", runtime.GOOS, runtime.GOARCH)
	}
}

func validatePackageName(name string) error {
	if !validName.MatchString(name) {
		return fmt.Errorf("invalid package name %q", name)
	}
	return nil
}

func (c *client) command() *cobra.Command {
	var prefix string
	root := &cobra.Command{
		Use:               "bm",
		Short:             "Install packages from " + defaultRegistry,
		SilenceUsage:      true,
		SilenceErrors:     true,
		CompletionOptions: cobra.CompletionOptions{DisableDefaultCmd: true},
	}
	root.SetOut(c.output)
	root.SetErr(c.stderr)
	root.PersistentFlags().StringVar(&prefix, "prefix", "", "installation prefix (default: ~/.local)")

	var file, linkTo string
	var noLink bool
	install := &cobra.Command{
		Use:   "install [package...]",
		Short: "Install packages from arguments and a YAML file",
		Args: func(cmd *cobra.Command, args []string) error {
			if len(args) == 0 && file == "" {
				return fmt.Errorf("provide at least one package or --file")
			}
			if noLink && cmd.Flags().Changed("link-to") {
				return fmt.Errorf("--no-link and --link-to cannot be used together")
			}
			return nil
		},
		RunE: func(cmd *cobra.Command, args []string) error {
			config := manifest{}
			var err error
			if file != "" {
				config, err = loadManifest(file)
				if err != nil {
					return err
				}
			}
			if cmd.Flags().Changed("prefix") {
				config.Prefix = prefix
			} else if config.Prefix == "" {
				config.Prefix, err = defaultPrefix()
				if err != nil {
					return err
				}
			}
			if len(args) > 0 {
				if noLink {
					linkTo = ""
				}
				config.Installs = append(config.Installs, installGroup{Packages: args, LinkTo: linkTo})
			}
			plan, err := config.plan()
			if err != nil {
				return err
			}
			return c.install(cmd.Context(), config.Prefix, plan)
		},
	}
	install.Flags().StringVarP(&file, "file", "f", "", "YAML installation plan")
	install.Flags().StringVar(&linkTo, "link-to", ".", "link CLI packages below the prefix")
	install.Flags().BoolVar(&noLink, "no-link", false, "install CLI packages without links")

	remove := &cobra.Command{
		Use:   "remove <package>...",
		Short: "Remove packages and their links",
		Args:  cobra.MinimumNArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			if prefix == "" {
				var err error
				prefix, err = defaultPrefix()
				if err != nil {
					return err
				}
			}
			return c.remove(prefix, args)
		},
	}

	root.AddCommand(install, remove)
	return root
}

func (c *client) execute(ctx context.Context, args []string) error {
	command := c.command()
	command.SetArgs(args)
	return command.ExecuteContext(ctx)
}

func main() {
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()
	c := newClient(defaultRegistry, os.Stdout, os.Stderr)
	if err := c.execute(ctx, os.Args[1:]); err != nil {
		fmt.Fprintln(os.Stderr, "error:", err)
		os.Exit(1)
	}
}
