# GnuPG — minimal command-line feature set.
#
# Why local:
# 1. The standalone product needs command-line OpenPGP support, not GUI tools.
# 2. Selecting the minimal, GUI-free upstream configuration keeps those
#    dependencies out of every consumer, including the static GPGME build.
#
# This is intentional feature selection, not an upstream regression.
{ gnupg }:

gnupg.override {
  enableMinimal = true;
  guiSupport = false;
}
