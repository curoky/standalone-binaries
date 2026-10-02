# libewf — OpenSSL configure probes for same-architecture cross builds.
#
# Why local:
# 1. Configure uses `AC_RUN_IFELSE` for two OpenSSL behavior probes and aborts
#    when it detects cross compilation.
# 2. Nixpkgs supplies cached answers only when the build platform cannot execute
#    the host platform. This repository crosses from glibc to musl on the same
#    architecture, so that predicate is true even though Autoconf still reports
#    `cross_compiling=yes`.
# 3. Key the cached answers on differing build/host triples instead. Radare2 and
#    Rizin receive this derivation explicitly.
#
# Remove this override when upstream handles same-architecture libc crosses.
{
  lib,
  stdenv,
  libewf,
}:

libewf.overrideAttrs (old: {
  configureFlags =
    (old.configureFlags or [ ])
    ++ lib.optionals (stdenv.hostPlatform.config != stdenv.buildPlatform.config) [
      "ac_cv_openssl_xts_duplicate_keys=yes"
      "ac_cv_openssl_evp_zlib_compatible=yes"
    ];
})
