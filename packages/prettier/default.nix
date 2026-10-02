# Prettier — JavaScript payload with a sibling Node runtime.
#
# Why local:
# 1. The nixpkgs package builds correctly, but its generated launcher retains
#    the Node interpreter selected inside the Nix store.
# 2. Build the upstream distribution with `nodejs-slim26` so its generation and
#    checks use the same runtime version that the standalone product publishes.
# 3. Copy only the JavaScript distribution and replace the launcher with one
#    that finds the separately deployed Node sibling by relative path.
#
# This is intentional runtime packaging, not an upstream build workaround.
{
  lib,
  stdenvNoCC,
  writeText,
  prettier,
  nodejs-slim26,
}:

let
  prettierStatic = prettier.override { nodejs = nodejs-slim26; };
  wrapper = writeText "prettier-wrapper.sh" ''
    #!/usr/bin/env bash
    script_path="$(readlink -f "$0")"
    root="$(cd "$(dirname "$script_path")/.." && pwd)"
    store="$(cd "$root/.." && pwd)"
    exec "$store/nodejs-slim26/bin/node" "$root/libexec/prettier/bin/prettier.cjs" "$@"
  '';
in
stdenvNoCC.mkDerivation {
  pname = "prettier";
  inherit (prettierStatic) version;

  dontUnpack = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/libexec
    cp -R ${prettierStatic}/lib/node_modules/prettier $out/libexec/prettier

    mkdir -p $out/bin
    cp ${wrapper} $out/bin/prettier
    chmod +x $out/bin/prettier

    runHook postInstall
  '';

  meta = {
    description = "prettier running on the sibling standalone node package";
    homepage = "https://prettier.io/";
    license = lib.licenses.mit;
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    mainProgram = "prettier";
  };
}
