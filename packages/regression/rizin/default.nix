# Rizin — musl-static dependency and cross-build fixes.
#
# Why local:
#   Rizin asks Meson for a build-machine C compiler but its nixpkgs
#   derivation does not provide one for the musl cross build. Add only that
#   build-for-build compiler.
#
#   Its native build-time utility needs pcre2 and softfloat wrap subprojects,
#   but Meson cannot download them in the sandbox. Populate the native wrap
#   names from the matching sources already present in the Rizin tarball.
#
#   Bundled libdemangle still uses `both_libraries()` and attempts to link an
#   unusable shared object under the static toolchain. Make that target honor
#   Meson's static default.
#
# Remove each fix when the corresponding stock dependency or derivation works.
{
  buildPackages,
  rizin,
  tree-sitter,
}:

(rizin.override {
  inherit tree-sitter;
}).overrideAttrs
  (old: {
    depsBuildBuild = (old.depsBuildBuild or [ ]) ++ [ buildPackages.stdenv.cc ];
    postPatch = (old.postPatch or "") + ''
      substituteInPlace subprojects/libdemangle/meson.build \
        --replace-fail 'libdemangle = both_libraries(' 'libdemangle = library(' \
        --replace-fail 'libdemangle.get_static_lib()' 'libdemangle' \
        --replace-fail 'libdemangle.get_shared_lib()' 'libdemangle'
      cp -r subprojects/pcre2-10.47 subprojects/pcre2_cross_native
      cp subprojects/packagefiles/pcre2_cross_native/meson.build \
        subprojects/pcre2_cross_native/meson.build
      cp -r subprojects/softfloat subprojects/softfloat_cross_native
    '';
  })
