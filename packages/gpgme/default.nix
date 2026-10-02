# gpgme — reduced GnuPG closure for musl-static.
#
# Why local:
# 1. Stock GPGME pulls in full GnuPG, whose openldap dependency aborts because
#    Cyrus SASL cannot be located in the static build.
# 2. GPGME's checks invoke bare target `gpgconf` and `gpgsm`, which are not
#    executable from the cross-test sandbox.
# 3. The override supplies minimal, GUI-free GnuPG and disables those checks.
#
# Regress the dependency reduction and checks independently when stock supports
# them under musl-static.
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
