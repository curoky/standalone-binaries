# poppler-utils — musl-static build of the CLI utilities only.
#
# Stock `poppler-utils` is rejected under musl-static because default features
# pull in `nss -> p11-kit` (badPlatforms = isStatic). Build `minimal + utils`,
# then also disable openjpeg (otherwise `libtiff -> giflib` forces a shared
# lib) and `BUILD_TESTING`. The `minimal` build drops poppler's own transitive
# linkage, so the CLIs no longer resolve fontconfig/freetype/expat/bzip2/brotli
# symbols. HarfBuzz's CMake target also omits its private graphite2 archive.
# The CMakeLists patches append those static archives in dependency order.
# graphite2 and HarfBuzz use Python only as a build-time tool. pkgsStatic gives
# them the target static Python, whose ctypes cannot load FreeType while
# collecting fonttools tests. Inject native Python while keeping graphite2,
# HarfBuzz and Poppler themselves static.
{
  lib,
  stdenv,
  poppler,
  harfbuzz,
  graphite2,
  nativePython3,
  fontconfig,
  freetype,
  expat,
  bzip2,
  brotli,
  openjpeg,
  poppler_data,
  dejavu_fonts,
  writeText,
}:
let
  wrapperScript = writeText "poppler-wrapper.sh" ''
    #!/usr/bin/env sh

    script_path=$0
    case "$script_path" in
      /*) ;;
      *) script_path=$PWD/$script_path ;;
    esac
    while [ -L "$script_path" ]; do
      link=$(readlink "$script_path")
      case "$link" in
        /*) script_path=$link ;;
        *) script_path=$(dirname "$script_path")/$link ;;
      esac
    done
    root=$(CDPATH= cd "$(dirname "$script_path")/.." && pwd -P)

    export FONTCONFIG_FILE="$root/etc/fonts/fonts.conf"
    export POPPLER_DATADIR="$root/share/poppler"
    exec "$root/bin/_''${0##*/}" "$@"
  '';
  fontconfigForPoppler =
    if stdenv.hostPlatform.isDarwin then
      fontconfig.overrideAttrs (oldAttrs: {
        # fontconfig's Meson check misses xlocale.h with the static Darwin SDK,
        # but fcint.h needs its LC_*_MASK definitions. Its path tests also
        # assume /tmp is not canonicalized to macOS's /private/tmp.
        doCheck = false;
        postPatch = (oldAttrs.postPatch or "") + ''
          substituteInPlace src/fcint.h \
            --replace-fail $'#include <locale.h>\n#include <math.h>' \
                           $'#include <locale.h>\n#include <xlocale.h>\n#include <math.h>'
        '';
      })
    else
      fontconfig;
  graphite2WithNativePython = graphite2.override { python3 = nativePython3; };
  harfbuzzWithNativeGraphite2 =
    let
      harfbuzzWithGraphite2 = harfbuzz.override {
        graphite2 = graphite2WithNativePython;
        python3 = nativePython3;
        withIntrospection = false;
        withCoreText = false;
      };
    in
    if stdenv.hostPlatform.isDarwin then
      harfbuzzWithGraphite2.overrideAttrs (oldAttrs: {
        # Poppler only consumes the core HarfBuzz libraries. Disable optional
        # GLib/GObject APIs, docs and CoreText: static GLib cannot detect the
        # Darwin subsystem, and static consumers otherwise inherit unrecorded
        # CoreText framework symbols.
        nativeBuildInputs = lib.filter (
          input:
          !(builtins.elem (input.pname or null) [
            "glib"
            "gtk-doc"
            "docbook-xsl-nons"
            "docbook-xml"
          ])
        ) (oldAttrs.nativeBuildInputs or [ ]);
        buildInputs = lib.filter (input: (input.pname or null) != "glib") (oldAttrs.buildInputs or [ ]);
        propagatedBuildInputs = lib.filter (input: (input.pname or null) != "glib") (
          oldAttrs.propagatedBuildInputs or [ ]
        );
        outputs = lib.filter (output: output != "devdoc") oldAttrs.outputs;
        mesonFlags = (oldAttrs.mesonFlags or [ ]) ++ [
          "-Ddocs=disabled"
          "-Dglib=disabled"
          "-Dgobject=disabled"
        ];
      })
    else
      harfbuzzWithGraphite2;
  popplerLibsOld = "set(poppler_LIBS \${poppler_LIBS} Fontconfig::Fontconfig)";
  popplerLibsNew =
    "set(poppler_LIBS\n"
    + "  \${poppler_LIBS}\n"
    + "  Fontconfig::Fontconfig\n"
    + "  ${fontconfigForPoppler.lib}/lib/libfontconfig.a\n"
    + "  ${freetype}/lib/libfreetype.a\n"
    + "  ${expat}/lib/libexpat.a\n"
    + "  ${bzip2.out}/lib/libbz2.a\n"
    + "  ${brotli.lib}/lib/libbrotlidec.a\n"
    + "  ${brotli.lib}/lib/libbrotlicommon.a\n"
    + ")\n";
  popplerHarfBuzzLibsOld = "set(poppler_LIBS \${poppler_LIBS} harfbuzz::harfbuzz harfbuzz::subset)";
  popplerHarfBuzzLibsNew =
    "set(poppler_LIBS \${poppler_LIBS} harfbuzz::harfbuzz harfbuzz::subset "
    + "${graphite2WithNativePython}/lib/libgraphite2.a)";
in
(poppler.override {
  suffix = "utils";
  utils = true;
  minimal = true;
  harfbuzz = harfbuzzWithNativeGraphite2;
  fontconfig = fontconfigForPoppler;
}).overrideAttrs
  (oldAttrs: {
    # Linux musl-static stock poppler-utils first pulls in nss -> p11-kit, then
    # openjpeg -> libtiff -> giflib. The utils we ship do not need either chain.
    propagatedBuildInputs = lib.subtractLists [ openjpeg ] oldAttrs.propagatedBuildInputs;
    doCheck = false;
    patches = (oldAttrs.patches or [ ]) ++ [ ./relative-data-dir.patch ];
    cmakeFlags = (oldAttrs.cmakeFlags or [ ]) ++ [
      "-DENABLE_LIBOPENJPEG=OFF"
      "-DBUILD_TESTING=OFF"
    ];
    postPatch = (oldAttrs.postPatch or "") + ''
      substituteInPlace CMakeLists.txt \
        --replace-fail ${lib.escapeShellArg popplerLibsOld} ${lib.escapeShellArg popplerLibsNew} \
        --replace-fail ${lib.escapeShellArg popplerHarfBuzzLibsOld} ${lib.escapeShellArg popplerHarfBuzzLibsNew}
    '';
    postInstall = (oldAttrs.postInstall or "") + ''
      mkdir -p "$out/etc/fonts" "$out/share/fonts"
      cp -R ${fontconfigForPoppler.out}/etc/fonts/. "$out/etc/fonts/"
      cp -R ${fontconfigForPoppler.out}/share/fontconfig "$out/share/"
      cp -R ${dejavu_fonts.minimal}/share/fonts/. "$out/share/fonts/"
      cp -R ${poppler_data}/share/poppler "$out/share/"
      chmod -R u+w "$out/etc/fonts" "$out/share"
      substituteInPlace "$out/etc/fonts/fonts.conf" \
        --replace-fail '<include ignore_missing="yes">/etc/fonts/conf.d</include>' \
                       '<include ignore_missing="yes">conf.d</include>' \
        --replace-fail '<dir>${dejavu_fonts.minimal}</dir>' \
                       '<dir prefix="relative">../../share/fonts</dir>'

      for name in pdfattach pdfdetach pdffonts pdfimages pdfinfo pdfseparate pdftohtml pdftoppm pdftops pdftotext pdfunite; do
        mv "$out/bin/$name" "$out/bin/_$name"
        cp ${wrapperScript} "$out/bin/$name"
        chmod +x "$out/bin/$name"
      done
    '';
  })
