# atuin
#
# The whole upstream static `atuin` output plus a pre-generated zsh init script
# so shells do not have to shell out to `atuin init zsh ...` on every startup.
#
# The upstream output (bin/atuin, bin/atuin-daemon, bin/atuin-pty-proxy, shell
# completions, ...) is copied verbatim; this package only *adds* the init
# script, it does not select or drop any of the binaries upstream ships.
#
#   $store/atuin/
#     bin/atuin            (the static binary, from pkgsStatic.atuin)
#     bin/atuin-daemon     (and any other binaries upstream ships)
#     share/atuin/init.zsh (pre-generated; source it from ~/.zshrc)
#
# `atuin init zsh` emits a script that calls the bare command name `atuin`,
# relying on it being on PATH. To keep the relocatable tarball self-contained,
# the init script is prefixed with a prologue that resolves the co-located
# binary relative to the sourced script itself
# (share/atuin/init.zsh -> ../../bin/atuin) and:
#   * defines an `atuin` shell function so interactive hooks/widgets use the
#     bundled binary regardless of PATH, and
#   * prepends the bundled bin dir to PATH so the tmux-popup `sh -c` subshell
#     (which re-exports the current PATH) can also find it.
#
# The init text only depends on the atuin version, not the target
# architecture, so it is produced with the native build-platform binary
# (`nativeAtuin`); the shipped binary stays the cross/static one.
{
  lib,
  stdenvNoCC,
  atuin,
  # Native (build-platform) atuin of the same version, used only to emit the
  # init text at build time. Injected explicitly from the flake because
  # callPackage resolves `atuin` from the cross/static set.
  nativeAtuin,
}:

stdenvNoCC.mkDerivation {
  pname = "atuin";
  inherit (atuin) version;

  dontUnpack = true;

  installPhase = ''
    runHook preInstall

    # Copy the upstream output verbatim (atuin, atuin-daemon, atuin-pty-proxy,
    # shell completions, ...); this package only *adds* the init script below,
    # it must not pick or drop any of the binaries upstream ships.
    cp -R ${atuin}/. $out
    chmod -R u+w $out
    mkdir -p $out/share/atuin

    # `atuin init` loads client settings, which wants a writable config dir;
    # the sandbox HOME (/homeless-shelter) is read-only, so point it at $TMPDIR.
    export HOME="$TMPDIR/home"
    mkdir -p "$HOME"
    "${lib.getExe nativeAtuin}" init zsh --disable-up-arrow --disable-ai \
      > "$TMPDIR/init.zsh"

    # Resolve atuin relative to the sourced init script (zsh: %x is the path of
    # the file currently being sourced), then make the bundled binary the one
    # the emitted bare `atuin` calls resolve to.
    {
      printf '%s\n' '__atuin_dir="''${''${(%):-%x}:A:h}"'
      printf '%s\n' '__atuin_bin_dir="''${__atuin_dir}/../../bin"'
      printf '%s\n' 'atuin() { "''${__atuin_bin_dir}/atuin" "$@" }'
      printf '%s\n' 'export PATH="''${__atuin_bin_dir}:''${PATH}"'
      cat "$TMPDIR/init.zsh"
    } > $out/share/atuin/init.zsh

    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck

    # No /nix/store path may survive in the emitted script.
    if grep -q '/nix/store' $out/share/atuin/init.zsh; then
      echo "atuin init.zsh still contains a /nix/store path" >&2
      exit 1
    fi
    grep -q '__atuin_bin_dir' $out/share/atuin/init.zsh

    runHook postInstallCheck
  '';

  meta = atuin.meta // {
    mainProgram = "atuin";
  };
}
