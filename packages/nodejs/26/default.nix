# Node.js 26 — versioned musl-static runtime.
#
# Why local:
# 1. Gyp imports ctypes, which the static target Python cannot load. Configure
#    with build-platform Python instead.
# 2. Ada's tests expect fuzzer executables that its static build does not
#    produce, so disable only that dependency's checks.
# 3. LIEF forces Python bindings, reaching a pydantic-core cdylib that the
#    static Rust target cannot build. Node needs only LIEF's C/C++ library, so
#    remove the Python output and propagated Python closure.
# 4. Temporal's install check invokes unprefixed pkg-config and runs target test
#    programs in the cross sandbox. Disable that dependency check only.
# 5. Static stdenv appends autotools flags that Node's Python configure script
#    rejects; remove `--enable-static` and `--disable-shared` from that input.
# 6. System Brotli, simdutf and merve archives have link-order or version
#    mismatches. Use Node's mutually matched bundled copies.
# 7. Node's checks build `.node` shared addons with a non-PIC static CRT and fail
#    on `__TMC_END__` relocations, so checks remain disabled.
# 8. Dependency overrides are guarded by `hostPlatform.isStatic`; applying them
#    to build-platform copies would invalidate cached CMake/LLVM/Rust toolchains.
#
# The Node 26 output is a product version. Regress each build workaround
# independently when stock `pkgsStatic.nodejs_26` supports it.
{
  lib,
  pkgsStatic,
  python3,
}:

let
  onlyStatic =
    pkg: overrides: if pkg.stdenv.hostPlatform.isStatic then pkg.overrideAttrs overrides else pkg;
  pkgsStaticNode = pkgsStatic.extend (
    _: prev: {
      ada = onlyStatic prev.ada { doCheck = false; };
      # lief (linked by node since 25.6 via `useSharedLief`): the nixpkgs lief
      # package hardcodes `LIEF_PYTHON_API true` and builds Python bindings,
      # pulling in python3 + pydantic -> pydantic-core (a Rust/maturin cdylib).
      # Under pkgsStatic that chain is built for the musl static target, where
      # maturin cannot produce a cdylib ("target ... does not support these
      # crate types"), so the build fails on pydantic-core. node only needs
      # lief's C/C++ library (`out`), not the Python bindings (`py`), so build
      # lief with the Python API disabled to cut the whole Python dependency.
      #
      # The python deps (pydantic, build, pip, scikit-build-core, ...) reach
      # lief's runtime closure via `propagatedBuildInputs`, not `buildInputs`:
      # under pkgsStatic the python builders move host python libraries from
      # buildInputs into propagatedBuildInputs, so clearing buildInputs alone
      # leaves pydantic-core in the closure. We must also clear
      # propagatedBuildInputs (alongside dropping the `py` output and disabling
      # LIEF_PYTHON_API / the python build+install/import-check phases).
      lief = onlyStatic prev.lief (old: {
        outputs = [ "out" ];
        buildInputs = [ ];
        propagatedBuildInputs = [ ];
        cmakeFlags =
          builtins.filter (f: !(lib.hasInfix "LIEF_PYTHON_API" f) && !(lib.hasInfix "Python_EXECUTABLE" f)) (
            old.cmakeFlags or [ ]
          )
          ++ [ (lib.cmakeBool "LIEF_PYTHON_API" false) ];
        postBuild = "";
        postInstall = "";
        pythonImportsCheck = [ ];
      });
      # temporal_capi (new dependency in node 26, the Rust impl of the Temporal
      # API): its installCheckPhase compiles and *runs* C/C++ programs against
      # the freshly built lib. Under the static musl cross toolchain that check
      # breaks — the `pkg-config` it calls is the target-prefixed cross wrapper
      # (`x86_64-...-pkg-config`), so the bare `pkg-config` invocation fails with
      # "command not found", and the test binaries are static target binaries
      # not meant to run in the build sandbox. node only needs the resulting
      # library / headers / .pc file, so skip the install check.
      temporal_capi = onlyStatic prev.temporal_capi { doInstallCheck = false; };
    }
  );

  patchedNode = (pkgsStaticNode.nodejs-slim_26.override { python3 = python3; }).overrideAttrs (old: {
    configureFlags = builtins.filter (
      f:
      f != "--enable-static"
      && f != "--disable-shared"
      # Make node use its own bundled copies of brotli, simdutf and merve
      # (the cjs-module-lexer C++ lib) instead of the system static libraries:
      #   - brotli: the system static build ships split archives
      #     (libbrotli{common,enc,dec}.a) which the single-pass musl GNU ld
      #     fails to link in the right order, leaving common symbols (e.g.
      #     `_kBrotliPrefixCodeRanges`) undefined.
      #   - simdutf: node bundles a simdutf version matched to its sources; the
      #     system static simdutf can lag behind, causing undefined references
      #     at link time when node references newer simdutf API.
      #   - merve (new dependency in node 26): the system `merve` (cjs-module-
      #     lexer) is compiled against the system simdutf, so libmerve.a
      #     references `simdutf::detail::find`, a symbol absent from node's
      #     bundled simdutf — linking node_mksnapshot then fails with an
      #     undefined reference. Bundling merve makes it use node's own simdutf.
      && f != "--shared-brotli"
      && f != "--shared-simdutf"
      && f != "--shared-merve"
      && !(lib.hasPrefix "--shared-brotli-libpath=" f)
      && !(lib.hasPrefix "--shared-simdutf-libpath=" f)
      && !(lib.hasPrefix "--shared-merve-libpath=" f)
    ) old.configureFlags;
    buildInputs = builtins.filter (
      p:
      !(lib.hasInfix "brotli" (p.name or ""))
      && !(lib.hasInfix "simdutf" (p.name or ""))
      && !(lib.hasInfix "merve" (p.name or ""))
    ) (old.buildInputs or [ ]);
    # The check phase builds native test addons (test/js-native-api/*,
    # build-{js-native,node}-api-tests) which link `.node` shared objects.
    # Under the fully static (musl) gcc toolchain that fails with `relocation
    # R_X86_64_32 against hidden symbol __TMC_END__ can not be used when making
    # a shared object` (static CRT crtbeginT.o is not PIC). These test addons
    # are irrelevant to the node binary, so skip the checks.
    doCheck = false;
  });
in
patchedNode.overrideAttrs (_: {
  pname = "nodejs-slim26";
  __intentionallyOverridingVersion = true;
})
