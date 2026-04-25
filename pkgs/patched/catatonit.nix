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
