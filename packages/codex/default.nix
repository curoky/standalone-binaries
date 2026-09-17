{
  lib,
  stdenv,
  codex,
  emptyFile,
  perl,
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
# We also drop upstream's `postFixup`, which used `wrapProgram` to bake the
# nixpkgs `ripgrep`/`bubblewrap` store paths into PATH. That violates our
# no-`/nix/store` invariant. codex already locates `rg` and `bwrap` from the
# ambient PATH at runtime, so the sibling tools must simply be installed
# alongside (`bm` does not resolve dependencies).
(codex.override {
  librusty_v8 = emptyFile;
  librusty_v8_src_binding = emptyFile;
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
    ];

    # Upstream shell-completion generation and the wrapProgram PATH injection
    # both bake nixpkgs store paths into the output; neither is compatible with
    # our relocatable, no-store-reference outputs. rg / bwrap come from PATH.
    postFixup = "";
  })
