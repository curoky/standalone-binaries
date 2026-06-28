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
