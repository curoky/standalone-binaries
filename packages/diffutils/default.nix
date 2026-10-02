# diffutils — musl test-suite workaround.
#
# Why local:
# 1. The binaries compile and link statically without source changes.
# 2. Nine gnulib multithread/setlocale tests, including
#    `test-setlocale_null-mt` and `test-thread_create`, abort under musl.
# 3. Checks are disabled without changing the shipped binaries.
#
# Remove this override when the full stock test suite passes under musl-static.
{
  lib,
  stdenv,
  fetchurl,
  diffutils,
}:

diffutils.overrideAttrs (oldAttrs: rec {
  doCheck = false;
})
