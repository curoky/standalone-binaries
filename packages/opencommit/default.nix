# opencommit (on static node)
#
# opencommit running on our fully-static (musl) `nodejs-slim24` package, instead
# of being `nix bundle`'d into a self-extracting executable. Same approach as
# packages/pnpm: the interpreter is overridden upstream-style in
# packages/local.nix (it is a buildNpmPackage tool, so its `buildNpmPackage` is
# overridden with `nodejs = nodejs-slim24`), so the `opencommit` argument here is
# already built against our static node. This derivation reuses that tool's JS
# distribution and ships a relative-path wrapper that invokes the sibling static
# node explicitly, so the static node travels with the deployed tool instead of
# depending on a node on the host PATH after the standalone normalize pass.
#
# Upstream nixpkgs ships opencommit as:
#   $out/bin/{opencommit,oco}                  (wrappers invoking node)
#   $out/lib/node_modules/opencommit/...        (the JS + node_modules)
#
# Deploy layout:
#   $store/
#     nodejs-slim24/bin/node      (separate package; static musl ELF)
#     opencommit/
#       bin/{opencommit,oco}      (wrappers -> sibling node + out/cli.cjs)
#       libexec/opencommit/...    (JS, from the nixpkgs opencommit)
#
# Verification:
#   $out/bin/opencommit --version   # (with sibling node present)
{
  lib,
  stdenvNoCC,
  writeText,
  opencommit,
}:

let
  wrapper = writeText "opencommit-wrapper.sh" ''
    #!/usr/bin/env bash
    script_path="$(readlink -f "$0")"
    root="$(cd "$(dirname "$script_path")/.." && pwd)"
    store="$(cd "$root/.." && pwd)"
    exec "$store/nodejs-slim24/bin/node" "$root/libexec/opencommit/out/cli.cjs" "$@"
  '';
in
stdenvNoCC.mkDerivation {
  pname = "opencommit";
  inherit (opencommit) version;

  dontUnpack = true;

  installPhase = ''
    runHook preInstall

    # Reuse the upstream nixpkgs opencommit's JS distribution.
    mkdir -p $out/libexec
    cp -R ${opencommit}/lib/node_modules/opencommit $out/libexec/opencommit

    # Replace the upstream bin wrappers with relative-path wrappers that invoke
    # the sibling static node explicitly.
    mkdir -p $out/bin
    cp ${wrapper} $out/bin/opencommit
    cp ${wrapper} $out/bin/oco
    chmod +x $out/bin/opencommit $out/bin/oco

    runHook postInstall
  '';

  meta = {
    description = "opencommit running on the sibling fully-static (musl) node package";
    homepage = "https://github.com/di-sukharev/opencommit";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
    mainProgram = "opencommit";
  };
}
