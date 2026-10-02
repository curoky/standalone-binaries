# Cross-static producer overrides for tools that execute only while building.
#
# Why local:
# 1. nixpkgs normally selects `__spliced.buildHost` for nativeBuildInputs, but
#    composed environments such as `python3.withPackages` no longer carry that
#    splice metadata. Graphite2 and Rizin therefore receive target-static
#    Python environments that either cannot load ctypes or are not executable
#    on a different build architecture.
# 2. Some expressions put build-only interpreters in `buildInputs`, where
#    automatic splicing deliberately keeps the target package. Wget does this
#    for Perl on Darwin; Rizin and Radare2 do it for source generators.
# 3. Node's Gyp configure path and Darwin rsync's build hooks also execute
#    Python during the build. None of these interpreters is linked into or
#    shipped with the corresponding product.
# 4. Override the producer once so every consumer inherits the native tool.
#    The current failures happen to involve Python and Perl, but the platform
#    rule also applies to compilers, linkers, code generators, build systems,
#    and test tools. Add them here only when a patched producer actually picks
#    a target tool for build-only execution.
# 5. Do not replace `pkgsStatic.python3`, `pkgsStatic.perl`, or their package
#    sets: runtimes and packages embedding an interpreter still require the
#    target-static interpreter and libraries.
#
# Every override is restricted to the static target scope because
# `pkgsStatic.extend` also evaluates the overlay for buildPackages. Remove each
# entry independently when its upstream expression selects the build-platform
# interpreter without a local override.
{
  lib,
  nativePkgs,
}:
_: prev:
let
  useNativeBuildTools = name: tools: {
    "${name}" = prev.${name}.override tools;
  };
in
lib.optionalAttrs prev.stdenv.hostPlatform.isStatic (
  lib.optionalAttrs (prev ? graphite2) (
    useNativeBuildTools "graphite2" { python3 = nativePkgs.python3; }
  )
  // lib.optionalAttrs (prev.stdenv.hostPlatform.isLinux && prev ? nodejs-slim_24) (
    useNativeBuildTools "nodejs-slim_24" { python3 = nativePkgs.python3; }
  )
  // lib.optionalAttrs (prev.stdenv.hostPlatform.isLinux && prev ? nodejs-slim_26) (
    useNativeBuildTools "nodejs-slim_26" { python3 = nativePkgs.python3; }
  )
  // lib.optionalAttrs (prev.stdenv.hostPlatform.isLinux && prev ? radare2) (
    useNativeBuildTools "radare2" { perl = nativePkgs.perl; }
  )
  // lib.optionalAttrs (prev.stdenv.hostPlatform.isLinux && prev ? rizin) (
    useNativeBuildTools "rizin" {
      perl = nativePkgs.perl;
      python3 = nativePkgs.python3;
    }
  )
  // lib.optionalAttrs (prev.stdenv.hostPlatform.isDarwin && prev ? rsync) (
    useNativeBuildTools "rsync" { python3 = nativePkgs.python3; }
  )
  // lib.optionalAttrs (prev.stdenv.hostPlatform.isDarwin && prev ? wget) (
    useNativeBuildTools "wget" { perlPackages = nativePkgs.perlPackages; }
  )
)
