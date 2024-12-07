# make-standalone.nix
#
# Wrap a derivation so its output becomes a self-contained, "standalone"
# payload suitable for shipping to minimal/foreign environments:
#   - copy the output into a fresh, writable $out
#   - run scripts/normalize.sh over the tree to strip binaries, rewrite
#     Nix store references, drop docs/manpages, and inline external symlinks
#
# This is purely a post-processing/normalization step; it does not change how
# the underlying package is built (static vs dynamic). See DESIGN.md.
{
  pkgs,
  normalizeScript,
}:
name: drv:
pkgs.runCommand "${name}-standalone"
  {
    nativeBuildInputs = [
      pkgs.buildPackages.binutils
      pkgs.buildPackages.file
      pkgs.buildPackages.nukeReferences
    ];
    builderScript = normalizeScript;
  }
  ''
    mkdir -p $out
    cp -pRP ${drv}/* $out/ 2>/dev/null || true
    chmod -R u+w $out

    bash $builderScript $out
  ''
