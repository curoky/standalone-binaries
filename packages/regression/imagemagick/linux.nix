# Stock pkgsStatic ImageMagick is blocked by several dependency failures. Potrace
# finds a working system getopt_long during the musl cross build but cannot run
# its argument-order probe, falls back to its bundled pre-ANSI getopt, and that
# copy fails to compile with GCC 16. Keep the delegate and teach only this
# dependency to use musl's already-detected getopt_long. LibRaw's sample tools
# link its C++ archive with the C linker and fail on unresolved C++ ABI symbols,
# static librsvg cannot find libunwind during Meson configuration, libheif's
# static rav1e still tries to install a nonexistent shared object, and libjxl's
# example misses static Brotli symbols. Disable only those RAW, RSVG, HEIF and
# JXL delegates instead of weakening dependency checks. The stock frozen paths
# are absolute store paths, so enable ImageMagick's own embedded configuration
# mode to keep colors, delegates and policy available after relocation. Remove
# dependency overrides independently once each stock dependency builds; keep
# zero-configuration until stock paths are relocatable.
{
  imagemagick,
  potrace,
}:
(imagemagick.override {
  librawSupport = false;
  librsvgSupport = false;
  libheifSupport = false;
  libjxlSupport = false;
  potrace = potrace.overrideAttrs (oldAttrs: {
    patches = (oldAttrs.patches or [ ]) ++ [ ./potrace-cross-getopt.patch ];
  });
}).overrideAttrs
  (oldAttrs: {
    configureFlags = (oldAttrs.configureFlags or [ ]) ++ [ "--enable-zero-configuration" ];
  })
