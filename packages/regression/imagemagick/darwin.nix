# Stock pkgsStatic ImageMagick enables FFTW on Darwin. FFTW propagates static
# OpenMP, whose current package graph reaches a broken target Python and makes
# ImageMagick fail during evaluation. FFTW is an optional acceleration feature;
# keep all image-format delegates and disable only it. shared-mime-info's
# fetchFromGitLab source also fails while Nix imports its extracted calc.sct
# fixture into the Darwin store. Keep the same verified upstream archive as a
# flat fixed-output source so stdenv extracts it inside the package build, and
# apply it to the static librsvg delegate and DjVu's native librsvg build tool.
# The generated Meson cross file calls Darwin ARM64 "arm64", which dav1d does
# not recognize and causes it to compile ARM32 assembly; GLib and Pango cannot
# detect their subsystem because the cross file also omits Meson's "macos"
# subsystem. Layer a package-specific cross file with both canonical values and
# inject the patched GLib through all ImageMagick delegates that consume it.
# HarfBuzz's HarfBust font forms its diagnostic ligature through CoreText on
# current macOS, contrary to that single test's expected output. Keep the
# OpenType assertion and all other CoreText tests.
# libheif's example-only heifio helper discovers static libtiff, whose exported
# CMake target omits its Deflate target definition. Disable TIFF only in that
# helper; ImageMagick keeps its own TIFF delegate and libheif codecs.
# Stock x265 deletes every static archive after building them, so libheif sees
# its headers but cannot enable HEIC encoding. Keep the archive only in this
# dependency graph.
# Static fontconfig on Darwin includes locale.h but not xlocale.h, leaving
# locale_t and LC_*_MASK undefined. Add the missing include and inject the
# patched package through Cairo, Pango, librsvg, and ImageMagick so the stock
# fontconfig does not remain in the dependency graph.
# Static libraw builds its C examples with the C linker even though libraw is
# C++, leaving libc++ symbols unresolved. ImageMagick consumes only the library,
# so disable examples without removing RAW format support.
# ImageMagick's static librsvg link omits the Apple iconv archive needed by
# GLib, libxml2, and gettext. Add the archive and its final link flag without
# changing SVG support.
# Fontconfig and its minimal DejaVu font otherwise remain at build-time store
# paths. Bundle both and use a relative wrapper so text rendering survives
# relocation.
# The stock frozen paths are absolute store paths, so ImageMagick's embedded
# zero-configuration mode keeps runtime configuration after relocation. Remove
# each dependency workaround once its stock package builds; keep
# zero-configuration until stock paths are relocatable.
{
  buildPackages,
  cairo,
  dav1d,
  dejavu_fonts,
  djvulibre,
  fetchurl,
  fontconfig,
  gdk-pixbuf,
  glib,
  harfbuzz,
  imagemagick,
  libheif,
  libiconv,
  libjxl,
  liblqr1,
  libraw,
  libraqm,
  librsvg,
  makeFontsConf,
  pango,
  shared-mime-info,
  stdenv,
  writeText,
  x265,
}:
let
  wrapperScript = writeText "imagemagick-wrapper.sh" ''
    #!/usr/bin/env sh

    command=''${0##*/}
    script_path=$0
    case "$script_path" in
      /*) ;;
      *) script_path=$PWD/$script_path ;;
    esac
    bin_dir=''${script_path%/*}
    root=$(CDPATH= cd "$bin_dir/.." && pwd -P)

    export FONTCONFIG_FILE="$root/etc/fonts/fonts.conf"
    if [ "$command" = magick ]; then
      exec "$root/bin/_magick" "$@"
    else
      exec "$root/bin/_magick" "$command" "$@"
    fi
  '';
  replaceInput =
    pname: replacement:
    builtins.map (input: if (input.pname or null) == pname then replacement else input);
  sharedMimeInfoSource = fetchurl {
    url = "https://gitlab.freedesktop.org/api/v4/projects/xdg%2Fshared-mime-info/repository/archive.tar.gz?sha=refs%2Ftags%2F2.5.1";
    name = "shared-mime-info-2.5.1.tar.gz";
    hash = "sha256-wCXuYyFwDwsv1o/DwJZvo99k9luJDQ/K3abGSoa10xM=";
  };
  nativeSharedMimeInfo = buildPackages.shared-mime-info.overrideAttrs {
    src = sharedMimeInfoSource;
  };
  nativeLibrsvgWithArchiveSource = buildPackages.librsvg.override {
    shared-mime-info = nativeSharedMimeInfo;
  };
  staticSharedMimeInfo = (shared-mime-info.override {
    glib = glibWithMesonCpuFamily;
    shared-mime-info = nativeSharedMimeInfo;
  }).overrideAttrs
    {
      src = sharedMimeInfoSource;
    };
  fontconfigWithXlocale = fontconfig.overrideAttrs (oldAttrs: {
    # The static Darwin SDK exposes locale_t and LC_*_MASK in xlocale.h.
    # Its path tests also assume /tmp is not canonicalized to /private/tmp.
    doCheck = false;
    postPatch = (oldAttrs.postPatch or "") + ''
      substituteInPlace src/fcint.h \
        --replace-fail $'#include <locale.h>\n#include <math.h>' \
                       $'#include <locale.h>\n#include <xlocale.h>\n#include <math.h>'
    '';
  });
  cairoWithFontconfig = cairo.override {
    fontconfig = fontconfigWithXlocale;
    glib = glibWithMesonCpuFamily;
  };
  gdkPixbufWithGlib =
    (gdk-pixbuf.override {
      glib = glibWithMesonCpuFamily;
    }).overrideAttrs
      (oldAttrs: {
        nativeBuildInputs = replaceInput "glib" buildPackages.glib (oldAttrs.nativeBuildInputs or [ ]);
      });
  harfbuzzWithGlib =
    (harfbuzz.override {
      glib = glibWithMesonCpuFamily;
    }).overrideAttrs
      (oldAttrs: {
        nativeBuildInputs = replaceInput "glib" buildPackages.glib (oldAttrs.nativeBuildInputs or [ ]);
        postPatch = (oldAttrs.postPatch or "") + ''
          substituteInPlace test/shape/data/in-house/tests/harfbust.tests \
            --replace-fail '@shapers=ot,coretext' '@shapers=ot'
        '';
      });
  makeFontsConfWithFontconfig =
    args:
    makeFontsConf (
      args
      // {
        fontconfig = fontconfigWithXlocale;
      }
    );
  pangoWithFontconfig =
    (pango.override {
      cairo = cairoWithFontconfig;
      glib = glibWithMesonCpuFamily;
      harfbuzz = harfbuzzWithGlib;
      makeFontsConf = makeFontsConfWithFontconfig;
    }).overrideAttrs
      (oldAttrs: {
        mesonFlags = (oldAttrs.mesonFlags or [ ]) ++ [ "--cross-file=${aarch64MesonCpuFamily}" ];
        nativeBuildInputs = replaceInput "glib" buildPackages.glib (oldAttrs.nativeBuildInputs or [ ]);
      });
  librsvgWithArchiveSource = librsvg.override {
    cairo = cairoWithFontconfig;
    dav1d = dav1dWithMesonCpuFamily;
    gdk-pixbuf = gdkPixbufWithGlib;
    glib = glibWithMesonCpuFamily;
    pango = pangoWithFontconfig;
    shared-mime-info = staticSharedMimeInfo;
  };
  djvulibreWithArchiveSource = djvulibre.override {
    librsvg = nativeLibrsvgWithArchiveSource;
  };
  aarch64MesonCpuFamily = writeText "aarch64-cross-file.conf" ''
    [host_machine]
    cpu_family = 'aarch64'
    subsystem = 'macos'

    [binaries]
    objc = '${stdenv.cc.targetPrefix}clang'
  '';
  dav1dWithMesonCpuFamily = dav1d.overrideAttrs (oldAttrs: {
    mesonFlags = (oldAttrs.mesonFlags or [ ]) ++ [ "--cross-file=${aarch64MesonCpuFamily}" ];
  });
  glibWithMesonCpuFamily = glib.overrideAttrs (oldAttrs: {
    mesonFlags = (oldAttrs.mesonFlags or [ ]) ++ [ "--cross-file=${aarch64MesonCpuFamily}" ];
  });
  libjxlWithGdkPixbuf =
    (libjxl.override {
      gdk-pixbuf = gdkPixbufWithGlib;
    }).overrideAttrs
      (oldAttrs: {
        nativeBuildInputs = replaceInput "gdk-pixbuf" buildPackages.gdk-pixbuf (
          oldAttrs.nativeBuildInputs or [ ]
        );
      });
  libheifWithDav1d =
    (libheif.override {
      dav1d = dav1dWithMesonCpuFamily;
      gdk-pixbuf = gdkPixbufWithGlib;
      x265 = x265WithStaticLibrary;
    }).overrideAttrs
      (oldAttrs: {
        cmakeFlags = (oldAttrs.cmakeFlags or [ ]) ++ [ "-DCMAKE_DISABLE_FIND_PACKAGE_TIFF=ON" ];
        postPatch = (oldAttrs.postPatch or "") + ''
          substituteInPlace cmake/modules/FindX265.cmake \
            --replace-fail 'set(X265_PROCESS_LIBS X265_LIBRARY)' \
            'find_library(X265_LIBRARY_10BIT NAMES x265-10 HINTS ''${X265_PKGCONF_LIBRARY_DIRS})
          find_library(X265_LIBRARY_12BIT NAMES x265-12 HINTS ''${X265_PKGCONF_LIBRARY_DIRS})
          set(X265_PROCESS_LIBS X265_LIBRARY X265_LIBRARY_10BIT X265_LIBRARY_12BIT)'
        '';
      });
  x265WithStaticLibrary = x265.overrideAttrs {
    postInstall = ''
      install -Dm444 libx265-10.a "$out/lib/libx265-10.a"
      install -Dm444 libx265-12.a "$out/lib/libx265-12.a"
      substituteInPlace "$out/lib/pkgconfig/x265.pc" \
        --replace-fail 'Libs.private: -lc++ -ldl' \
                       'Libs.private: -lx265-10 -lx265-12 -lc++ -ldl'
    '';
  };
  liblqrWithGlib = liblqr1.override {
    glib = glibWithMesonCpuFamily;
  };
  librawWithoutExamples = libraw.overrideAttrs (oldAttrs: {
    configureFlags = (oldAttrs.configureFlags or [ ]) ++ [ "--disable-examples" ];
  });
  libraqmWithHarfbuzz = libraqm.override {
    harfbuzz = harfbuzzWithGlib;
  };
in
(imagemagick.override {
  djvulibre = djvulibreWithArchiveSource;
  fftwSupport = false;
  fontconfig = fontconfigWithXlocale;
  libheif = libheifWithDav1d;
  libjxl = libjxlWithGdkPixbuf;
  liblqr1 = liblqrWithGlib;
  libraw = librawWithoutExamples;
  libraqm = libraqmWithHarfbuzz;
  librsvg = librsvgWithArchiveSource;
  pango = pangoWithFontconfig;
}).overrideAttrs
  (oldAttrs: {
    buildInputs = (oldAttrs.buildInputs or [ ]) ++ [ libiconv ];
    configureFlags = (oldAttrs.configureFlags or [ ]) ++ [ "--enable-zero-configuration" ];
    env = (oldAttrs.env or { }) // {
      NIX_LDFLAGS = (oldAttrs.env.NIX_LDFLAGS or "") + " -liconv";
    };
    postInstall = (oldAttrs.postInstall or "") + ''
      mkdir -p "$out/etc/fonts" "$out/share/fonts"
      cp -R ${fontconfigWithXlocale.out}/etc/fonts/. "$out/etc/fonts/"
      cp -R ${fontconfigWithXlocale.out}/share/fontconfig "$out/share/"
      cp -R ${dejavu_fonts.minimal}/share/fonts/. "$out/share/fonts/"
      chmod -R u+w "$out/etc/fonts" "$out/share"
      substituteInPlace "$out/etc/fonts/fonts.conf" \
        --replace-fail '<include ignore_missing="yes">/etc/fonts/conf.d</include>' \
                       '<include ignore_missing="yes">conf.d</include>' \
        --replace-fail '<dir>${dejavu_fonts.minimal}</dir>' \
                       '<dir prefix="relative">../../share/fonts</dir>'

      mv "$out/bin/magick" "$out/bin/_magick"
      cp ${wrapperScript} "$out/bin/magick"
      chmod +x "$out/bin/magick"
    '';
  })
