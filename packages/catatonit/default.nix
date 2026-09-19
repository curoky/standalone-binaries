# catatonit — musl-static build with the stock installCheck cleared.
#
# Upstream's installCheck runs `readelf` but never adds binutils to
# `nativeBuildInputs`; under the musl64 cross `strictDeps` build that fails with
# "readelf: command not found". Clear `installCheckPhase` to skip it.
{
  lib,
  stdenv,
  fetchurl,
  catatonit,
  glib,
  libseccomp,
  pkg-config,
}:

catatonit.overrideAttrs (oldAttrs: rec {
  installCheckPhase = "";
})
