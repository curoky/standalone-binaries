# FFmpeg for Linux — headless static codec set.
#
# Why local:
# 1. PulseAudio is unsupported for static targets. OpenMPT also propagates
#    mpg123, which pulls PulseAudio back in, so disable both inputs.
# 2. V4L2 propagates libbpf and elfutils, while VAAPI directly uses libva;
#    those dependency chains are unsupported for static targets.
# 3. ocl-icd's static test executable links duplicate OpenCL entry points and
#    aborts its build, so OpenCL support cannot enter the FFmpeg closure.
# 4. OpenAPV and the Vulkan loader unconditionally build shared libraries with
#    the static toolchain, which fails because its startup objects are not
#    valid in a shared object.
# 5. Xvid builds a shared library even for a static target; FFmpeg retains its
#    native MPEG-4 encoder without this optional external encoder.
# 6. LAME's decoder adds an undeclared mpg123 dependency to `libmp3lame.a`.
#    Disable only the decoder; FFmpeg's MP3 encoder remains available.
# 7. SoXR enables OpenMP without exposing libgomp in its pkg-config metadata,
#    so static consumers fail to link. Build SoXR without optional OpenMP.
# 8. libssh's pkg-config metadata omits its private crypto, compression, and
#    sodium dependencies, so add them for static consumers.
# 9. SVT-AV1's LTO archive does not expose its public symbols to the static
#     linker plugin. Disable LTO while retaining the encoder itself.
# 10. x265 deletes every installed static archive even when no shared library
#     exists on a static target. Its multibit archive also references 10/12-bit
#     side archives that are not installed. Keep a self-contained 8-bit archive.
# 11. libbluray and FFmpeg both export `dec_init`; the duplicate global symbol
#     makes the fully static ffmpeg executable impossible to link.
# 12. musl gives new threads a roughly 128 KiB default stack, but FFmpeg 9's
#     MPEG-TS PAT parser puts a `struct Program` larger than that on its input
#     thread stack. Record a 2 MiB PT_GNU_STACK size to prevent stack overflow.
#
# Restore each feature independently when its complete dependency chain builds
# as musl-static and the resulting artifact has no Nix store references.
{
  ffmpeg-headless,
  lame,
  libssh,
  soxr,
  svt-av1,
  x265,
}:

(ffmpeg-headless.override {
  lame = lame.override { decoderSupport = false; };
  libssh = libssh.overrideAttrs (old: {
    postFixup = old.postFixup + ''
      substituteInPlace $dev/lib/pkgconfig/libssh.pc \
        --replace-fail "Requires.private: " \
        "Requires.private: libcrypto zlib libsodium"
    '';
  });
  soxr = soxr.overrideAttrs (old: {
    cmakeFlags = old.cmakeFlags ++ [ "-DWITH_OPENMP=OFF" ];
  });
  svt-av1 = svt-av1.overrideAttrs (old: {
    cmakeFlags = map (
      flag: if flag == "-DSVT_AV1_LTO=ON" then "-DSVT_AV1_LTO=OFF" else flag
    ) old.cmakeFlags;
  });
  x265 = (x265.override { multibitdepthSupport = false; }).overrideAttrs {
    postInstall = "";
  };
  withBluray = false;
  withOpenmpt = false;
  withOpencl = false;
  withOpenapv = false;
  withPulse = false;
  withV4l2 = false;
  withVaapi = false;
  withVulkan = false;
  withXvid = false;
}).overrideAttrs
  (old: {
    configureFlags = old.configureFlags ++ [
      "--extra-ldflags=-Wl,-z,stack-size=2097152"
    ];
  })
