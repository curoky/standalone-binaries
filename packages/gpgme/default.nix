# gpgme — musl-static build backed by a minimal GnuPG.
#
# The stock full GnuPG dependency tree drags in openldap, which aborts with
# "Could not locate Cyrus SASL" under musl-static, so `minimalGnuPG`
# (enableMinimal, no GUI) must stay. Even with minimal GnuPG the checks are not
# recoverable: the static gpg-agent cannot start, so the test suite fails with
# "gpg: failed to start gpg-agent"; hence `--disable-gpg-test` and
# `doCheck = false`.
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
