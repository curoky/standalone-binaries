# FFmpeg for macOS — headless partial-static codec set.
#
# Why local:
# 1. Darwin Meson reports arm64 inconsistently for several static dependencies;
#    Opus, dav1d, Speex and the fontconfig/HarfBuzz/FreeType/libass chain fail
#    their architecture-specific builds. Their transitive users stay disabled.
# 2. zimg, vid-stab and OpenCL pull in static LLVM/OpenMP, whose CheckAtomic
#    probe cannot link libatomic on Darwin. Disable those features.
# 3. OpenAPV emits only a dylib even in `pkgsStatic`; GnuTLS, libssh, SRT and RIST
#    fail FFmpeg's static configure probes. Keeping any of them would either
#    fail the build or retain a Nix dylib.
# 4. Static iconv/libxml2 compile paths to conversion tables and catalogs that
#    this package does not ship. Disable iconv, XML and the dependent zvbi path.
# 5. LAME's decoder adds an undeclared mpg123 dependency to `libmp3lame.a`.
#    Disable only the decoder; FFmpeg's MP3 encoder remains available.
# 6. Nixpkgs deletes x265's sole static archive after installation, and its
#    multi-bit-depth archive references objects merged only into the shared
#    library. Preserve `libx265.a` and build the supported 8-bit variant.
# 7. FATE's `fate-seek-hls` asserts an environment-dependent packet size and
#    aborts the otherwise valid build, so checks remain disabled.
#
# Re-enable each feature or check independently when its stock static path
# builds without Nix dylibs or resource references.
{
  stdenv,
  ffmpeg-headless,
  lame,
  removeReferencesTo,
  x265,
}:

let
  ffmpeg_static =
    (ffmpeg-headless.override {
      lame = lame.override { decoderSupport = false; };
      x265 = (x265.override { multibitdepthSupport = false; }).overrideAttrs (_: {
        postInstall = "";
      });
      withOpenapv = false;
      withOpus = false;
      withDav1d = false;
      withFontconfig = false;
      withFribidi = false;
      withHarfbuzz = false;
      withIconv = false;
      withAss = false;
      withFreetype = false;
      withSpeex = false;
      withBluray = false;
      withOpenmpt = false;
      withVmaf = false;
      withZimg = false;
      withVidStab = false;
      withOpencl = false;
      withGnutls = false;
      withSsh = false;
      withSrt = false;
      withRist = false;
      withXml2 = false;
      withZvbi = false;
    }).overrideAttrs
      (_: {
        # nixpkgs enables ffmpeg's FATE suite whenever the build platform can
        # execute the host binaries, which is the case for native aarch64-darwin.
        # `fate-seek-hls` is an upstream-flaky test (it asserts an exact muxed
        # packet size that drifts across environments, e.g. 3860 vs 3904) and its
        # failure aborts the whole build. The test suite validates upstream ffmpeg,
        # not our packaging, so disable it.
        doCheck = false;
      });
in

stdenv.mkDerivation {
  pname = "ffmpeg";
  version = ffmpeg-headless.version;

  dontUnpack = true;

  nativeBuildInputs = [ removeReferencesTo ];

  installPhase = ''
    mkdir -p $out
    cp -r ${ffmpeg_static.bin}/bin $out/bin
    chmod -R u+w $out/bin

    # This standalone package does not ship the disabled libvpx presets or the
    # development-only data files, so remove their compiled-in fallback path.
    remove-references-to -t ${ffmpeg_static.data} $out/bin/*
  '';
}
