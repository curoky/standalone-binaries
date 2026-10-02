# markdownlint-cli2 — JavaScript payload with a sibling Node runtime.
#
# Why local:
# 1. The nixpkgs package builds correctly, but its generated launcher retains
#    the Node interpreter selected inside the Nix store.
# 2. Copy the JavaScript distribution without that launcher and install a
#    wrapper that finds the separately deployed `nodejs-slim26` sibling.
# 3. Run the install check directly through that Node runtime so it validates
#    the shipped JavaScript entry point without introducing a store fallback.
#
# This is intentional runtime packaging, not an upstream build workaround.
{
  lib,
  stdenvNoCC,
  writeText,
  markdownlint-cli2,
  nodejs-slim26,
}:

let
  wrapper = writeText "markdownlint-cli2-wrapper.sh" ''
    #!/usr/bin/env bash
    script_path="$(readlink -f "$0")"
    root="$(cd "$(dirname "$script_path")/.." && pwd)"
    store="$(cd "$root/.." && pwd)"
    exec "$store/nodejs-slim26/bin/node" "$root/libexec/markdownlint-cli2/markdownlint-cli2-bin.mjs" "$@"
  '';
in
stdenvNoCC.mkDerivation {
  pname = "markdownlint-cli2";
  inherit (markdownlint-cli2) version;

  dontUnpack = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/libexec
    cp -R ${markdownlint-cli2}/lib/node_modules/markdownlint-cli2 $out/libexec/markdownlint-cli2

    mkdir -p $out/bin
    cp ${wrapper} $out/bin/markdownlint-cli2
    chmod +x $out/bin/markdownlint-cli2

    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    check_dir=$(mktemp -d)
    printf '# Title\n\nHello world.\n' > "$check_dir/ok.md"
    ( cd "$check_dir" && ${nodejs-slim26}/bin/node \
        $out/libexec/markdownlint-cli2/markdownlint-cli2-bin.mjs ok.md )
    runHook postInstallCheck
  '';

  meta = {
    description = "markdownlint-cli2 running on the sibling standalone node package";
    homepage = "https://github.com/DavidAnson/markdownlint-cli2";
    license = lib.licenses.mit;
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    mainProgram = "markdownlint-cli2";
  };
}
