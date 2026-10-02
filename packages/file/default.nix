# file — relocatable magic database.
#
# Why local:
# 1. The executable's default magic database path points into its Nix output,
#    which is invalid after artifact relocation.
# 2. Rename the real executable and wrap it with an explicit path to the
#    co-located `magic.mgc`.
# 3. Nixpkgs' version hook would execute the wrapper before the standalone
#    layout exists, so direct that build-time check at the real executable.
#
# The wrapper is permanent packaging; remove the version-hook override when the
# upstream check supports wrapped entry points.
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
  versionCheckProgram = "${builtins.placeholder "out"}/bin/_file";

  postInstall = (oldAttrs.postInstall or "") + ''
    mv $out/bin/file $out/bin/_file
    cp ${wrapperScript} $out/bin/file
    chmod +x $out/bin/file
  '';
})
