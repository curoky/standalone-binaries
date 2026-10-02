# catatonit — install-check tool fix.
#
# Why local:
# 1. Upstream's install check runs `readelf -d` to assert static linkage but does
#    not declare binutils in `nativeBuildInputs`.
# 2. `strictDeps` therefore hides readelf in the musl cross build and the check
#    fails with `readelf: command not found`.
# 3. The check needs an unprefixed build-machine command; direct
#    `buildPackages.binutils` still installs a target-prefixed tool, so the
#    override uses build-for-build binutils.
#
# Remove this override once upstream declares the correct check dependency.
{
  lib,
  stdenv,
  fetchurl,
  catatonit,
  glib,
  libseccomp,
  pkg-config,
  buildPackages,
}:

catatonit.overrideAttrs (oldAttrs: {
  nativeBuildInputs = (oldAttrs.nativeBuildInputs or [ ]) ++ [
    buildPackages.buildPackages.binutils
  ];
})
