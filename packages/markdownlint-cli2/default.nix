# markdownlint-cli2 (on static node)
#
# markdownlint-cli2 running on our fully-static (musl) `nodejs-slim24` package,
# instead of being `nix bundle`'d into a self-extracting executable. Same
# approach as packages/pnpm: the interpreter is overridden upstream-style in
# packages/local.nix (it is a buildNpmPackage tool, so its `buildNpmPackage` is
# overridden with `nodejs = nodejs-slim24`), so the `markdownlint-cli2` argument
# here is already built against our static node. This derivation reuses that
# tool's JS distribution and ships a relative-path wrapper that invokes the
# sibling static node explicitly, so the static node travels with the deployed
# tool instead of depending on a node on the host PATH after the standalone
# normalize pass.
#
# Upstream nixpkgs ships markdownlint-cli2 as:
#   $out/bin/markdownlint-cli2                          (wrapper invoking node)
#   $out/lib/node_modules/markdownlint-cli2/...         (the JS + node_modules)
#
# Deploy layout:
#   $store/
#     nodejs-slim24/bin/node            (separate package; static musl ELF)
#     markdownlint-cli2/
#       bin/markdownlint-cli2           (wrapper -> sibling node + entry .mjs)
#       libexec/markdownlint-cli2/...   (JS, from the nixpkgs markdownlint-cli2)
#
# Verification:
#   $out/bin/markdownlint-cli2 --help   # (with sibling node present)
{
  lib,
  stdenvNoCC,
  writeText,
  markdownlint-cli2,
}:

let
  wrapper = writeText "markdownlint-cli2-wrapper.sh" ''
    #!/usr/bin/env bash
    script_path="$(readlink -f "$0")"
    root="$(cd "$(dirname "$script_path")/.." && pwd)"
    store="$(cd "$root/.." && pwd)"
    exec "$store/nodejs-slim24/bin/node" "$root/libexec/markdownlint-cli2/markdownlint-cli2-bin.mjs" "$@"
  '';
in
stdenvNoCC.mkDerivation {
  pname = "markdownlint-cli2";
  inherit (markdownlint-cli2) version;

  dontUnpack = true;

  installPhase = ''
    runHook preInstall

    # Reuse the upstream nixpkgs markdownlint-cli2's JS distribution.
    mkdir -p $out/libexec
    cp -R ${markdownlint-cli2}/lib/node_modules/markdownlint-cli2 $out/libexec/markdownlint-cli2

    # Replace the upstream bin wrapper with a relative-path wrapper that invokes
    # the sibling static node explicitly.
    mkdir -p $out/bin
    cp ${wrapper} $out/bin/markdownlint-cli2
    chmod +x $out/bin/markdownlint-cli2

    runHook postInstall
  '';

  meta = {
    description = "markdownlint-cli2 running on the sibling fully-static (musl) node package";
    homepage = "https://github.com/DavidAnson/markdownlint-cli2";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
    mainProgram = "markdownlint-cli2";
  };
}
