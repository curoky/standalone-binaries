# atuin
#
# Upstream static `atuin` plus a pre-generated zsh init script so shells do not
# have to shell out to `atuin init zsh ...` on every startup.
#
#   $store/atuin/
#     bin/atuin            (the static binary, from pkgsStatic.atuin)
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

let
  # The musl-static cross build's checkPhase flakes on a pty-proxy screen-paint
  # timing test (`a_stalled_client_does_not_wedge_the_socket_server`: "screen
  # never painted"). It is a terminal-rendering timing assertion unrelated to
  # the shipped functionality, so skip just that test on the static build.
  atuinBin =
    if atuin.stdenv.hostPlatform.isStatic then
      atuin.overrideAttrs (old: {
        checkFlags = (old.checkFlags or [ ]) ++ [
          "--skip=a_stalled_client_does_not_wedge_the_socket_server"
        ];
      })
    else
      atuin;
in

stdenvNoCC.mkDerivation {
  pname = "atuin";
  inherit (atuin) version;

  dontUnpack = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin $out/share/atuin
    cp ${lib.getExe atuinBin} $out/bin/atuin
    chmod +x $out/bin/atuin

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
