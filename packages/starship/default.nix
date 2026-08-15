# starship
#
# Upstream static `starship` plus a pre-generated zsh init script so shells do
# not have to shell out to `starship init zsh` on every startup.
#
#   $store/starship/
#     bin/starship            (the static binary, from pkgsStatic.starship)
#     share/starship/init.zsh (pre-generated; source it from ~/.zshrc)
#
# `starship init zsh` bakes the absolute path of the invoked binary into the
# emitted script. Since the tarball is relocatable, that path is rewritten to
# resolve `starship` relative to the sourced init script itself
# (share/starship/init.zsh -> ../../bin/starship), so no absolute or
# /nix/store path survives.
#
# The init text only depends on the starship version, not the target
# architecture, so it is produced with the native build-platform binary
# (`nativeStarship`); the shipped binary stays the cross/static one.
{
  lib,
  stdenvNoCC,
  starship,
  # Native (build-platform) starship of the same version, used only to emit the
  # init text at build time. Injected explicitly from the flake because
  # callPackage resolves `starship` from the cross/static set.
  nativeStarship,
}:

stdenvNoCC.mkDerivation {
  pname = "starship";
  inherit (starship) version;

  dontUnpack = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin $out/share/starship
    cp ${lib.getExe starship} $out/bin/starship
    chmod +x $out/bin/starship

    # starship bakes the absolute path of the invoked binary (resolved via
    # current_exe, so symlinks are canonicalised) into the emitted script.
    ${lib.getExe nativeStarship} init zsh > "$TMPDIR/init.zsh"

    # Resolve starship relative to the sourced init script (zsh: %x is the path
    # of the file currently being sourced), then rewrite the baked-in native
    # store path to that relative binary.
    {
      printf '%s\n' '__starship_dir="''${''${(%):-%x}:A:h}"'
      printf '%s\n' '__starship_bin="''${__starship_dir}/../../bin/starship"'
      sed 's#${lib.getExe nativeStarship}#''${__starship_bin}#g' "$TMPDIR/init.zsh"
    } > $out/share/starship/init.zsh

    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck

    # No /nix/store path may survive in the emitted script.
    if grep -q '/nix/store' $out/share/starship/init.zsh; then
      echo "starship init.zsh still contains an absolute path" >&2
      exit 1
    fi
    grep -q '__starship_bin' $out/share/starship/init.zsh

    runHook postInstallCheck
  '';

  meta = starship.meta // {
    mainProgram = "starship";
  };
}
