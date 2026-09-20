# catatonit — musl-static build with binutils added for the installCheck.
#
# Upstream's installCheck runs `readelf -d` to assert the binary is statically
# linked, but never adds binutils to `nativeBuildInputs`. Under the musl64
# cross `strictDeps` build the native PATH is isolated, so `readelf` is missing
# and the check fails with "readelf: command not found". Add binutils so the
# check runs instead of clearing it.
#
# The check invokes the unprefixed `readelf`, which only the build-for-build
# binutils provides: the direct `buildPackages.binutils` still targets the musl
# host and installs `x86_64-unknown-linux-musl-readelf`, so we reach one level
# deeper (`buildPackages.buildPackages`, targetPrefix = "") for a plain
# `readelf`.
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
