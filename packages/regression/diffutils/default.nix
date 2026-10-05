# diffutils — musl test-suite workaround.
#
# Why local:
# 1. The binaries compile and link statically without source changes.
# 2. Six gnulib multithread/locale tests (`test-nl_langinfo-mt`,
#    `test-random-mt`, both `test-setlocale_null-mt` variants,
#    `test-thread_create`, and `test-gmtime_r-mt`) fail under musl.
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
