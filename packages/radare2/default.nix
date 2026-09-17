{
  lib,
  stdenv,
  callPackage,
  radare2,
}:

# Stock radare2 fails to build under our musl-static cross set for two reasons:
#
#   1. It pulls in libewf, whose configure aborts on OpenSSL AC_RUN_IFELSE
#      probes it cannot run when cross compiling. Swap in the local libewf that
#      caches the failing probes.
#
#   2. Its bundled sdb subproject declares its library with meson
#      `both_libraries()`, so a libsdb .so is always built even though the static
#      build only link_wholes the static archive. Linking that .so under pure
#      musl-static fails with "R_X86_64_32 against hidden symbol __TMC_END__".
#      Turn sdb's library into a plain `library()` (respects
#      default_library=static → archive only) and point its remaining
#      `get_shared_lib()` reference at the static lib so no .so is produced.
#      radare2's meson also grabs the shared half via `get_shared_lib()`; redirect
#      that to the static archive it already link_wholes.
(radare2.override {
  libewf = callPackage ../libewf { };
}).overrideAttrs
  (old: {
    postUnpack =
      (old.postUnpack or "")
      + lib.optionalString stdenv.hostPlatform.isStatic ''
        substituteInPlace $sourceRoot/meson.build \
          --replace-fail \
            "libsdb_dynamic = libsdb_sp.get_variable('libsdb').get_shared_lib()" \
            "libsdb_dynamic = libsdb_static"
        substituteInPlace $sourceRoot/subprojects/sdb/meson.build \
          --replace-fail 'libsdb = both_libraries(libsdb_name' 'libsdb = library(libsdb_name' \
          --replace-fail 'link_with = libsdb.get_shared_lib()' 'link_with = libsdb' \
          --replace-fail 'link_with = libsdb.get_static_lib()' 'link_with = libsdb' \
          --replace-fail 'libraries: [libsdb.get_shared_lib()]' 'libraries: [libsdb]'
      '';
  })
