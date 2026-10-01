# gpgme — musl-static build backed by a minimal GnuPG.
#
# The stock full GnuPG dependency tree drags in openldap, which aborts with
# "Could not locate Cyrus SASL" under musl-static, so `minimalGnuPG`
# (enableMinimal, no GUI) must stay. `--disable-gpg-test` is no longer needed,
# but the checks still invoke bare `gpgconf` and `gpgsm`, which are unavailable
# in the cross test sandbox, so `doCheck = false` must stay.
{
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
  (_: {
    doCheck = false;
  })
