# diffutils — musl-static build with checks disabled.
#
# unstable diffutils 3.12's gnulib checkPhase fails 9 multithread/setlocale
# tests under musl-static (`test-setlocale_null-mt`, `test-thread_create`, ...
# with SIGABRT), so `doCheck = false`. This is the only customization.
{
  lib,
  stdenv,
  fetchurl,
  diffutils,
}:

diffutils.overrideAttrs (oldAttrs: rec {
  doCheck = false;
})
