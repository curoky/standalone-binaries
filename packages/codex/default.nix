# codex — musl-static CLI-only build.
#
# Why local:
# 1. Stock builds both the CLI and code-mode host. Only code-mode host depends
#    on V8, but denoland publishes no musl `librusty_v8` archive, so the full
#    derivation cannot fetch or link that target. Build only `codex-cli` and
#    replace the now-unused V8 sources with empty inputs.
# 2. Codex enables vendored OpenSSL on musl; openssl-sys then invokes Perl, which
#    stock omits from native build inputs. Supply build-machine Perl.
# 3. Nixpkgs resolves clang/libclang from the static target set even though they
#    are build tools for BoringSSL and bindgen. Use cached build-platform tools
#    so the target remains musl-static without rebuilding LLVM for musl.
# 4. Stock daemon-layout patch and `postInstall` package rg/bwrap/ps through
#    absolute store paths. The CLI uses PATH helpers; omit daemon packaging
#    and its patch so unused stock Ripgrep does not block the CLI build.
# 5. The CLI's onig_sys, tikv-jemalloc-sys and aws-lc-sys crates need system
#    libraries under the Cargo hook's no-vendoring policy.
#
# Regress these independently when upstream can build the full musl CLI output
# without V8 archives, missing build tools/libraries or store-path packaging.
{
  lib,
  codex,
  emptyFile,
  perl,
  oniguruma,
  rust-jemalloc-sys,
  aws-lc,
  buildPackages,
}:

(codex.override {
  librusty_v8 = emptyFile;
  librusty_v8_src_binding = emptyFile;
  clang = buildPackages.clang;
  libclang = buildPackages.libclang;
}).overrideAttrs
  (old: {
    patches = builtins.filter (
      patch: !(lib.hasSuffix "nix-package-layout.patch" (toString patch))
    ) old.patches;
    cargoBuildFlags = [
      "--package"
      "codex-cli"
    ];
    cargoCheckFlags = [
      "--package"
      "codex-cli"
    ];

    # codex-core pins `openssl-sys` to its `vendored` feature on musl targets,
    # so openssl-src compiles OpenSSL from source and needs perl on the build
    # machine.
    nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ perl ];
    buildInputs = old.buildInputs ++ [
      oniguruma
      rust-jemalloc-sys
      aws-lc
    ];

    env =
      builtins.removeAttrs (old.env or { }) [
        "RUSTY_V8_ARCHIVE"
        "RUSTY_V8_SRC_BINDING_PATH"
      ]
      // {
        # Re-point bindgen at the build-platform libclang overridden above; the
        # inherited value still referenced the target static libclang.
        LIBCLANG_PATH = "${lib.getLib buildPackages.libclang}/lib";
      };

    postInstall = "";
  })
