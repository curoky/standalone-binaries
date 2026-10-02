# Vim — relocatable runtime tree.
#
# Why local:
# 1. Stock Vim builds successfully, but its runtime discovery follows the Nix
#    installation prefix recorded by the packaged executable.
# 2. That path is invalid after the standalone directory is moved.
# 3. Keep the real binary private and set `VIMRUNTIME` from the wrapper's own
#    installed location unless the user supplied an explicit value.
#
# This is permanent runtime packaging, not an upstream build workaround.
{
  lib,
  stdenv,
  fetchurl,
  vim,
  writeText,
}:

let
  wrapperScript = writeText "wrapper.sh" ''
    #!/usr/bin/env bash

    script_path="$(readlink -f "$0")"
    root=$(cd "$(dirname "$script_path")" && pwd)/..

    if [[ -z $VIMRUNTIME ]]; then
      export VIMRUNTIME=$root/share/vim/vim92
    fi

    exec -a "$0" "$root/bin/_vim" "$@"
  '';
in

vim.overrideAttrs (oldAttrs: {
  postInstall = (oldAttrs.postInstall or "") + ''
    mv $out/bin/vim $out/bin/_vim
    cp ${wrapperScript} $out/bin/vim
    chmod +x $out/bin/vim
  '';
})
