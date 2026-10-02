# Makeself — relocatable archive header lookup.
#
# Why local:
# 1. Stock Makeself builds successfully, but its entry point refers to
#    `makeself-header.sh` through the Nix output path.
# 2. That compiled installation relationship is lost when the package moves.
# 3. Keep the real command private and wrap it with an explicit `--header` path
#    resolved from the installed executable.
#
# This is permanent runtime packaging, not an upstream build workaround.
{
  lib,
  stdenv,
  fetchurl,
  makeself,
  writeText,
}:

let
  wrapperScript = writeText "wrapper.sh" ''
    #!/usr/bin/env bash

    script_path="$(readlink -f "$0")"
    root=$(cd "$(dirname "$script_path")" && pwd)/..

    exec -a "$0" "$root/bin/_makeself" "--header" "$root/share/makeself/makeself-header.sh" "$@"
  '';
in

makeself.overrideAttrs (oldAttrs: {
  postInstall = (oldAttrs.postInstall or "") + ''
    mv $out/bin/makeself $out/bin/_makeself
    cp ${wrapperScript} $out/bin/makeself
    chmod +x $out/bin/makeself
  '';
})
