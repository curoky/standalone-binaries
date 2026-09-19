# conmon — musl-static build for podman's container monitor.
#
# Stock unstable's `propagatedBuildInputs` pulls in `systemd-minimal`, whose
# `meta.badPlatforms` includes `isStatic`, so the musl-static set is rejected
# at eval time. Narrow `buildInputs` to what conmon actually links and clear
# `propagatedBuildInputs`.
{
  lib,
  stdenv,
  fetchurl,
  conmon,
  glib,
  libseccomp,
  pkg-config,
}:

conmon.overrideAttrs (oldAttrs: rec {
  buildInputs = [
    glib
    libseccomp
  ];
  propagatedBuildInputs = [ ];
})
