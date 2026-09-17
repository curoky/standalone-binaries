{
  lib,
  stdenv,
  callPackage,
  buildPackages,
  rizin,
}:

# Stock rizin fails to build under our musl-static cross set for several reasons:
#
#   1. libewf's configure aborts on OpenSSL AC_RUN_IFELSE probes it cannot run
#      when cross compiling.
#   2. tree-sitter's `make install` tries to install a shared object the static
#      build never produces.
# Both are fixed by swapping in the local overrides.
#
#   3. rizin's meson.build calls `meson.get_compiler('c', native: true)`, which
#      needs a build-machine C compiler. The stock derivation omits
#      depsBuildBuild, so the cross build aborts with "Tried to access compiler
#      for language c, not specified for build machine". Provide the native cc.
#
#   4. On cross builds rizin compiles a *native* rz_util (to run sdb_gen at build
#      time), which pulls in native pcre2 and softfloat from the
#      `pcre2_cross_native` / `softfloat_cross_native` wrap subprojects. These
#      wraps are git/file downloads, disabled under -Dwrap_mode=nodownload, so
#      meson aborts with "Automatic wrap-based subproject downloading is
#      disabled". Populate both subproject directories from the source already
#      shipped in the tarball (pcre2-10.47 + its cross-native packagefiles, and
#      softfloat) so meson resolves them locally.
#
#   5. The bundled libdemangle subproject declares its library with
#      `both_libraries()`, so meson always builds a shared object even though the
#      static build only links the static archive. Linking that `.so` fails under
#      musl-static ("failed to set dynamic section sizes: bad value"). Turning it
#      into a plain `library()` respects default_library=static and only emits the
#      archive rizin actually uses.
(rizin.override {
  libewf = callPackage ../libewf { };
  tree-sitter = callPackage ../tree-sitter { };
}).overrideAttrs
  (old: {
    depsBuildBuild = (old.depsBuildBuild or [ ]) ++ [ buildPackages.stdenv.cc ];

    postPatch =
      (old.postPatch or "")
      + lib.optionalString stdenv.hostPlatform.isStatic ''
        substituteInPlace subprojects/libdemangle/meson.build \
          --replace-fail 'libdemangle = both_libraries(' 'libdemangle = library(' \
          --replace-fail 'libdemangle.get_static_lib()' 'libdemangle' \
          --replace-fail 'libdemangle.get_shared_lib()' 'libdemangle'
      ''
      + lib.optionalString (stdenv.hostPlatform.config != stdenv.buildPlatform.config) ''
        cp -r subprojects/pcre2-10.47 subprojects/pcre2_cross_native
        cp subprojects/packagefiles/pcre2_cross_native/meson.build \
          subprojects/pcre2_cross_native/meson.build
        cp -r subprojects/softfloat subprojects/softfloat_cross_native
      '';
  })
