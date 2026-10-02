# graphviz — static CLI subset with relocatable fonts.
#
# Why local:
# 1. Stock Graphviz enables LTDL, GUI/image plugins and their transitive dynamic
#    dependencies; several cannot build or link in the musl-static set.
# 2. The remaining CLI engines still need GD/font data. Build a minimal GD,
#    bundle DejaVu Sans with common aliases, and point `GDFONTPATH` at it through
#    a relative wrapper.
# 3. Publish only the static `dot` implementation and select each engine through
#    argv[0], removing libraries and development outputs from the product.
#
# Feature reductions are regression candidates; the CLI-only layout, aliases
# and bundled font are intentional packaging.
{
  lib,
  graphviz-nox,
  gd,
  dejavu_fonts,
}:

let
  gdMinimal =
    (gd.override {
      withXorg = false;
      libwebp = null;
      libtiff = null;
      libavif = null;
      fontconfig = null;
    }).overrideAttrs
      (oldAttrs: {
        buildInputs = builtins.filter (input: input != null) oldAttrs.buildInputs;
        configureFlags = (oldAttrs.configureFlags or [ ]) ++ [
          "--without-xpm"
          "--without-tiff"
          "--without-webp"
          "--without-avif"
          "--without-fontconfig"
        ];
      });
  wrapper = ./dot-wrapper.sh;
  engines = [
    "dot"
    "neato"
    "twopi"
    "fdp"
    "circo"
    "sfdp"
    "osage"
    "patchwork"
  ];
  fontAliases = [
    "times"
    "Times"
    "TIMES"
    "timesroman"
    "TimesRoman"
    "TIMESROMAN"
    "arial"
    "Arial"
    "ARIAL"
    "helvetica"
    "Helvetica"
    "HELVETICA"
    "courier"
    "Courier"
    "COURIER"
  ];
in

(graphviz-nox.override {
  gd = gdMinimal;
  pango = null;
  fontconfig = null;
}).overrideAttrs
  (oldAttrs: {
    buildInputs = builtins.filter (input: input != null) oldAttrs.buildInputs;
    configureFlags = (oldAttrs.configureFlags or [ ]) ++ [
      "--disable-ltdl"
      "--without-pangocairo"
      "--without-gdk"
      "--without-gdk-pixbuf"
      "--without-gtk"
      "--without-webp"
      "--without-poppler"
      "--without-rsvg"
    ];
    postInstall = (oldAttrs.postInstall or "") + ''
      cd "$out/bin"
      mv dot_static _dot
      cp ${wrapper} dot
      chmod 0555 dot
      ${lib.concatMapStringsSep "\n" (engine: "ln -s dot ${engine}") (lib.remove "dot" engines)}
      rm -f gvmap.sh

      rm -rf "$out/include" "$out/lib" "$out/nix-support"
      mkdir -p "$out/share/fonts"
      cp ${dejavu_fonts.minimal}/share/fonts/truetype/DejaVuSans.ttf "$out/share/fonts/"
      cd "$out/share/fonts"
      ${lib.concatMapStringsSep "\n" (name: "ln -s DejaVuSans.ttf ${name}.ttf") fontAliases}
    '';
    nativeInstallCheckInputs = [ ];
    doInstallCheck = true;
    installCheckPhase = ''
      runHook preInstallCheck

      export GDFONTPATH="$out/share/fonts"
      cd "$TMPDIR"
      printf 'digraph { a [label="Hello world"]; a -> b }\n' |
        "$out/bin/dot" -Tpng > graph.png
      printf 'graph { a -- b }\n' |
        "$out/bin/sfdp" -Tsvg > graph.svg
      test -s graph.png
      grep -q '<svg' graph.svg

      runHook postInstallCheck
    '';
  })
