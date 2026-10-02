# OpenCommit — JavaScript payload with a sibling Node runtime.
#
# Why local:
# 1. The nixpkgs package builds correctly, but its generated launchers retain the
#    Node interpreter selected inside the Nix store.
# 2. Copy the JavaScript distribution without those launchers and install the
#    same package-relative wrapper for both `opencommit` and `oco`.
# 3. The wrapper finds the separately deployed `nodejs-slim26`; the install
#    check invokes the shipped CLI module through that exact runtime.
#
# This is intentional runtime packaging, not an upstream build workaround.
{
  lib,
  stdenvNoCC,
  writeText,
  opencommit,
  nodejs-slim26,
}:

let
  wrapper = writeText "opencommit-wrapper.sh" ''
    #!/usr/bin/env bash
    script_path="$(readlink -f "$0")"
    root="$(cd "$(dirname "$script_path")/.." && pwd)"
    store="$(cd "$root/.." && pwd)"
    exec "$store/nodejs-slim26/bin/node" "$root/libexec/opencommit/out/cli.cjs" "$@"
  '';
in
stdenvNoCC.mkDerivation {
  pname = "opencommit";
  inherit (opencommit) version;

  dontUnpack = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/libexec
    cp -R ${opencommit}/lib/node_modules/opencommit $out/libexec/opencommit

    mkdir -p $out/bin
    cp ${wrapper} $out/bin/opencommit
    cp ${wrapper} $out/bin/oco
    chmod +x $out/bin/opencommit $out/bin/oco

    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    ${nodejs-slim26}/bin/node $out/libexec/opencommit/out/cli.cjs --version
    runHook postInstallCheck
  '';

  meta = {
    description = "opencommit running on the sibling standalone node package";
    homepage = "https://github.com/di-sukharev/opencommit";
    license = lib.licenses.mit;
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    mainProgram = "opencommit";
  };
}
