{
  lib,
  stdenv,
  fetchurl,
  file,
  writeText,
}:

let
  wrapperScript = writeText "wrapper.sh" ''
    #!/usr/bin/env bash

    script_path="$(readlink -f "$0")"
    root=$(cd "$(dirname "$script_path")" && pwd)/..

    exec -a "$0" "$root/bin/_file" "--magic-file" "$root/share/misc/magic.mgc" "$@"
  '';
in

file.overrideAttrs (oldAttrs: {
  # nixpkgs 5.48 enables versionCheckHook. Check the real executable because
  # postInstall replaces the public entry point with the relocatable wrapper.
  versionCheckProgram = "${builtins.placeholder "out"}/bin/_file";

  postInstall = (oldAttrs.postInstall or "") + ''
    mv $out/bin/file $out/bin/_file
    cp ${wrapperScript} $out/bin/file
    chmod +x $out/bin/file
  '';
})
