# poppler-utils — musl-static build of the CLI utilities only.
#
# Stock `poppler-utils` is rejected under musl-static because default features
# pull in `nss -> p11-kit` (badPlatforms = isStatic). Build `minimal + utils`,
# then also disable openjpeg (otherwise `libtiff -> giflib` forces a shared
# lib) and `BUILD_TESTING`. The `minimal` build drops poppler's own transitive
# linkage, so the CLIs no longer resolve fontconfig/freetype/expat/bzip2/brotli
# symbols. HarfBuzz's CMake target also omits its private graphite2 archive.
# The CMakeLists patches append those static archives in dependency order.
# graphite2 uses Python + fonttools only as build-time tools. pkgsStatic gives it
# the target static Python, whose ctypes cannot load FreeType while collecting
# fonttools tests. Inject native Python into graphite2 while keeping graphite2,
# harfbuzz and poppler themselves musl-static.
{
  lib,
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
}:
let
  graphite2WithNativePython = graphite2.override { python3 = nativePython3; };
  harfbuzzWithNativeGraphite2 = harfbuzz.override { graphite2 = graphite2WithNativePython; };
  popplerLibsOld = "set(poppler_LIBS \${poppler_LIBS} Fontconfig::Fontconfig)";
  popplerLibsNew =
    "set(poppler_LIBS\n"
    + "  \${poppler_LIBS}\n"
    + "  Fontconfig::Fontconfig\n"
    + "  ${fontconfig.lib}/lib/libfontconfig.a\n"
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
}).overrideAttrs
  (oldAttrs: {
    # Linux musl-static stock poppler-utils first pulls in nss -> p11-kit, then
    # openjpeg -> libtiff -> giflib. The utils we ship do not need either chain.
    propagatedBuildInputs = lib.subtractLists [ openjpeg ] oldAttrs.propagatedBuildInputs;
    doCheck = false;
    cmakeFlags = (oldAttrs.cmakeFlags or [ ]) ++ [
      "-DENABLE_LIBOPENJPEG=OFF"
      "-DBUILD_TESTING=OFF"
    ];
    postPatch = (oldAttrs.postPatch or "") + ''
      substituteInPlace CMakeLists.txt \
        --replace-fail ${lib.escapeShellArg popplerLibsOld} ${lib.escapeShellArg popplerLibsNew} \
        --replace-fail ${lib.escapeShellArg popplerHarfBuzzLibsOld} ${lib.escapeShellArg popplerHarfBuzzLibsNew}
    '';
  })
