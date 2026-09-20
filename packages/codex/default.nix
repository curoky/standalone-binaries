{
  lib,
  stdenv,
  codex,
  emptyFile,
  perl,
  buildPackages,
}:

# Stock `codex` (nixpkgs) builds two binaries: the `codex` CLI and a
# `codex-code-mode-host` companion. Only the companion pulls in V8 (via the
# `code-mode-runtime` -> `v8` crate chain); the `codex-cli` dependency graph
# never references `code-mode-*`, so the CLI itself does not link V8.
#
# V8 is the sole blocker for our musl-static build: nixpkgs injects a
# *pre-built* `librusty_v8` archive whose download URL is keyed on
# `rustcTarget`. denoland only publishes `*-linux-gnu` archives, so under our
# `*-linux-musl` static target the fetch has no matching hash, and even a
# force-fed gnu archive cannot link into a musl-static binary.
#
# Building only `codex-cli` drops the companion and therefore V8 entirely. We
# replace the two `librusty_v8*` inputs with empty files so the derivation stops
# fetching the (unavailable, unused) archive at eval time.
#
# codex's `nativeBuildInputs`/`buildInputs` pull in `clang` and `libclang`
# purely as *build-time* tooling: clang is the C compiler for the vendored
# BoringSSL/openssl-sys sources, and libclang backs bindgen (via
# `LIBCLANG_PATH`). Under our musl-static cross set, callPackage resolves both
# to the *target* `clang-static-*-musl`, which has no binary cache and forces a
# from-source rebuild of the entire LLVM/Clang toolchain (~1.5h each, OOM-kills
# CI runners). These tools run on the build platform, so we pull them from
# `buildPackages`, whose glibc `clang`/`libclang` are cached on
# `cache.nixos.org`. This does not affect the emitted binary: the target still
# links against musl-static via stdenv's gcc.
#
# We also drop upstream's `postFixup`, which used `wrapProgram` to bake the
# nixpkgs `ripgrep`/`bubblewrap` store paths into PATH. That violates our
# no-`/nix/store` invariant. codex already locates `rg` and `bwrap` from the
# ambient PATH at runtime, so the sibling tools must simply be installed
# alongside (`bm` does not resolve dependencies).
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

    env = builtins.removeAttrs (old.env or { }) [
      "RUSTY_V8_ARCHIVE"
      "RUSTY_V8_SRC_BINDING_PATH"
    ] // {
      # Re-point bindgen at the build-platform libclang overridden above; the
      # inherited value still referenced the target static libclang.
      LIBCLANG_PATH = "${lib.getLib buildPackages.libclang}/lib";
    };

    # Upstream shell-completion generation and the wrapProgram PATH injection
    # both bake nixpkgs store paths into the output; neither is compatible with
    # our relocatable, no-store-reference outputs. rg / bwrap come from PATH.
    postFixup = "";
  })
