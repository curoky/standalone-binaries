{
  lib,
  stdenv,
  libewf,
}:

# libewf's configure runs two AC_RUN_IFELSE OpenSSL probes
# (`ac_cv_openssl_xts_duplicate_keys` and `ac_cv_openssl_evp_zlib_compatible`)
# that abort with "cannot run test program while cross compiling". nixpkgs only
# provides the cache answer when `!buildPlatform.canExecute hostPlatform`, but
# our musl-static set is a same-arch cross (build gnu, host musl) where
# canExecute stays true, so the guard never fires while autoconf still sees
# cross_compiling=yes. Key off the build/host triple mismatch instead and cache
# both probes. radare2/rizin consume this fixed libewf via .override.
libewf.overrideAttrs (old: {
  configureFlags =
    (old.configureFlags or [ ])
    ++ lib.optionals (stdenv.hostPlatform.config != stdenv.buildPlatform.config) [
      "ac_cv_openssl_xts_duplicate_keys=yes"
      "ac_cv_openssl_evp_zlib_compatible=yes"
    ];
})
