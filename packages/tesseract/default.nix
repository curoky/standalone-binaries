# Tesseract — relocatable OCR language data.
#
# Why local:
# 1. Nixpkgs wraps the executable with an absolute TESSDATA_PREFIX and leaves
#    the real binary in a separate store output.
# 2. Artifact normalization removes those store paths, leaving a recursive
#    `exec tesseract` wrapper and an invalid `/share/tessdata` lookup.
# 3. Copy the real executable beside a wrapper that resolves its bundled data
#    relative to its installed location.
# 4. The upstream wrapper bundles every standard language model by default
#    (about 1 GiB). Ship only the accuracy-first tessdata_best models for
#    English, simplified Chinese, traditional Chinese, and orientation/script
#    detection; users can point TESSDATA_PREFIX at alternatives when needed.
#
# This is permanent runtime packaging, not an upstream build workaround.
{
  fetchurl,
  lib,
  stdenvNoCC,
  tesseract,
  writeText,
}:

let
  tessdataBest = import ./tessdata-best.nix { inherit fetchurl; };
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

    mkdir -p $out/bin $out/share/tessdata
    cp ${lib.getExe tesseract.tesseractBase} $out/bin/_tesseract
    cp ${wrapperScript} $out/bin/tesseract
    chmod +x $out/bin/tesseract
    cp -rL ${tesseract.tesseractBase}/share/tessdata/* $out/share/tessdata/
    cp -L ${tessdataBest.eng} $out/share/tessdata/eng.traineddata
    cp -L ${tessdataBest.chi_sim} $out/share/tessdata/chi_sim.traineddata
    cp -L ${tessdataBest.chi_tra} $out/share/tessdata/chi_tra.traineddata
    cp -L ${tessdataBest.osd} $out/share/tessdata/osd.traineddata

    runHook postInstall
  '';

  meta = tesseract.meta;
}
