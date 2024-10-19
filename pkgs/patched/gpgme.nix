{
  lib,
  stdenv,
  fetchurl,
  writeText,
  gnupg,
  gpgme,
}:
let
  minimalGnuPG = gnupg.override {
    enableMinimal = true;
    guiSupport = false;
  };
in
(gpgme.override {
  gnupg = minimalGnuPG;
}).overrideAttrs
  (oldAttrs: {
    configureFlags = (oldAttrs.configureFlags or [ ]) ++ [
      "--disable-gpg-test"
    ];
    doCheck = false;
  })
