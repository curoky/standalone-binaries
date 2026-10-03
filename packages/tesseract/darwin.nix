# Tesseract for Darwin — OCR runtime without training-only Pango.
#
# Why local:
# 1. Nixpkgs unconditionally adds Pango even though Tesseract only uses it for
#    optional training tools that are not part of this runtime artifact.
# 2. pkgsStatic.pango pulls in pkgsStatic.glib, whose Meson configuration cannot
#    detect a Darwin subsystem and aborts before Tesseract is built.
# 3. Removing Pango makes Tesseract's configure disable the training tools while
#    preserving the OCR CLI.
# 4. Static dependencies require GNU libiconv's `_libiconv*` ABI while other
#    dependencies require Darwin's `_iconv*` ABI. Both archives export the
#    unused `__libiconv_version` marker, so hide only the Apple copy's marker
#    before linking both implementations.
# 5. Nixpkgs wraps the executable with an absolute TESSDATA_PREFIX and leaves
#    the real binary in a separate store output, so package both independently
#    from the Linux implementation with a relative-path runtime wrapper.
#
# Delete only the base override when static GLib/Pango builds on Darwin and
# nixpkgs selects the Apple ABI iconv; keep the Darwin runtime packaging.
{
  darwinLibiconv,
  lib,
  nmedit,
  stdenvNoCC,
  tesseract,
  writeText,
}:

let
  tesseractBase = tesseract.tesseractBase.overrideAttrs (oldAttrs: {
    buildInputs = lib.filter (input: (input.pname or null) != "pango") (oldAttrs.buildInputs or [ ]);
    propagatedBuildInputs = lib.filter (input: (input.pname or null) != "pango") (
      oldAttrs.propagatedBuildInputs or [ ]
    );
    postConfigure = (oldAttrs.postConfigure or "") + ''
      cp ${darwinLibiconv}/lib/libiconv.a libiconv-apple.a
      chmod +w libiconv-apple.a
      printf '%s\n' __libiconv_version > remove-symbols
      ${nmedit} -R remove-symbols libiconv-apple.a
      substituteInPlace Makefile \
        --replace-fail "-liconv" "$PWD/libiconv-apple.a"
    '';
  });
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
    cp ${lib.getExe tesseractBase} $out/bin/_tesseract
    cp ${wrapperScript} $out/bin/tesseract
    chmod +x $out/bin/tesseract
    cp -rL ${tesseractBase}/share/tessdata/* $out/share/tessdata/
    cp -rL ${tesseract.tessdata}/* $out/share/tessdata/

    runHook postInstall
  '';

  meta = tesseract.meta;
}
