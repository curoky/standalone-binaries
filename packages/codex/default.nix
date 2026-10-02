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
# 4. Stock `postFixup` wraps rg/bwrap with absolute store paths. Drop it so
#    runtime helpers resolve from the deployed environment instead.
#
# Regress these independently when upstream can build the full musl CLI output
# without V8 archives, missing build tools or store-path wrappers.
{
  lib,
  stdenv,
  codex,
  emptyFile,
  perl,
  buildPackages,
}:

(codex.override {
  librusty_v8 = emptyFile;
  librusty_v8_src_binding = emptyFile;
  clang = buildPackages.clang;
  libclang = buildPackages.libclang;
}).overrideAttrs
  (old: {
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

    # Upstream shell-completion generation and the wrapProgram PATH injection
    # both bake nixpkgs store paths into the output; neither is compatible with
    # our relocatable, no-store-reference outputs. rg / bwrap come from PATH.
    postFixup = "";
  })
