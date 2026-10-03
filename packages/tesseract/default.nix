# Tesseract — relocatable OCR language data.
#
# Why local:
# 1. Nixpkgs wraps the executable with an absolute TESSDATA_PREFIX and leaves
#    the real binary in a separate store output.
# 2. Artifact normalization removes those store paths, leaving a recursive
#    `exec tesseract` wrapper and an invalid `/share/tessdata` lookup.
# 3. Copy the real executable beside a wrapper that resolves the complete
#    upstream language-data set relative to its installed location.
#
# This is permanent runtime packaging, not an upstream build workaround.
{
  lib,
  stdenvNoCC,
  tesseract,
  writeText,
}:

let
  wrapperScript = writeText "wrapper.sh" ''
    #!/usr/bin/env bash

    script_path="$(readlink -f "$0")"
    root=$(cd "$(dirname "$script_path")" && pwd)/..

    if [[ -z ''${TESSDATA_PREFIX+x} ]]; then
      export TESSDATA_PREFIX="$root/share/tessdata"
    fi

    exec -a "$0" "$root/bin/_tesseract" "$@"
  '';
in

stdenvNoCC.mkDerivation {
  pname = "tesseract";
  inherit (tesseract) version;

  dontUnpack = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin $out/share
    cp ${lib.getExe tesseract.tesseractBase} $out/bin/_tesseract
    cp ${wrapperScript} $out/bin/tesseract
    chmod +x $out/bin/tesseract
    cp -rL ${tesseract}/share/tessdata $out/share/tessdata

    runHook postInstall
  '';

  meta = tesseract.meta;
}
