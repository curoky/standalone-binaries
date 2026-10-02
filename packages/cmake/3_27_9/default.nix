# CMake 3.27.9 — versioned musl-static build.
#
# Why local:
# 1. This exact legacy version is a product output and is built from source
#    independently of the moving nixpkgs CMake attributes.
# 2. Its bundled cmcppdap omits `<cstdint>` and fails with current compilers;
#    inject the include before building.
# 3. The test suite links a shared module with the static CRT and fails on a
#    non-PIC `__TMC_END__` relocation, so `BUILD_TESTING` remains disabled.
# 4. OpenSSL, curses and system libraries are excluded deliberately to keep the
#    bootstrap self-contained; those are product choices, not regressions.
#
# Regress only the include and test workarounds; retain the versioned output and
# reduced dependency policy.
{
  lib,
  stdenv,
  fetchurl,
  buildPackages,
  pkg-config,
}:

# https://github.com/NixOS/nixpkgs/blob/791b761c6181525b897e6f0f6f6e80d3fe462eca/pkgs/by-name/cm/cmake/package.nix

stdenv.mkDerivation (finalAttrs: {
  pname = "cmake_3_27_9";

  version = "3.27.9";

  src = fetchurl {
    url = "https://cmake.org/files/v${lib.versions.majorMinor finalAttrs.version}/cmake-${finalAttrs.version}.tar.gz";
    hash = "sha256-YJqbmFcqal6kd/kSz/uXMQntTQpqaz+eI1PSzcBIcI4=";
  };

  patches = [ ];

  outputs = [ "out" ];
  setOutputFlags = false;

  setupHooks = [ ];

  depsBuildBuild = [ buildPackages.stdenv.cc ];

  nativeBuildInputs = finalAttrs.setupHooks ++ [
    pkg-config
  ];

  buildInputs = [ ];

  postPatch = ''
    sed -i '/#include <memory>/a #include <cstdint>' Utilities/cmcppdap/include/dap/network.h
  '';

  preConfigure = ''
    substituteInPlace Modules/Platform/UnixPaths.cmake \
      --subst-var-by libc_bin ${lib.getBin stdenv.cc.libc} \
      --subst-var-by libc_dev ${lib.getDev stdenv.cc.libc} \
      --subst-var-by libc_lib ${lib.getLib stdenv.cc.libc}
    # CC_FOR_BUILD and CXX_FOR_BUILD are used to bootstrap cmake
    configureFlags="--parallel=''${NIX_BUILD_CORES:-1} CC=$CC_FOR_BUILD CXX=$CXX_FOR_BUILD $configureFlags"
  '';

  # The configuration script is not autoconf-based, although being similar;
  # triples and other interesting info are passed via CMAKE_* environment
  # variables and commandline switches
  configurePlatforms = [ ];

  configureFlags = [
    "--docdir=share/doc/${finalAttrs.pname}-${finalAttrs.version}"
    "--no-system-libs"
  ]
  # Workaround https://gitlab.kitware.com/cmake/cmake/-/issues/20568
  ++ lib.optionals stdenv.hostPlatform.is32bit [
    "CFLAGS=-D_FILE_OFFSET_BITS=64"
    "CXXFLAGS=-D_FILE_OFFSET_BITS=64"
  ]
  # Workaround missing atomic ops with gcc <13
  ++ lib.optional stdenv.hostPlatform.isRiscV "LDFLAGS=-latomic"
  ++ [
    "--"
    # We should set the proper `CMAKE_SYSTEM_NAME`.
    # http://www.cmake.org/Wiki/CMake_Cross_Compiling
    #
    # Unfortunately cmake seems to expect absolute paths for ar, ranlib, and
    # strip. Otherwise they are taken to be relative to the source root of the
    # package being built.
    (lib.cmakeFeature "CMAKE_CXX_COMPILER" "${stdenv.cc.targetPrefix}c++")
    (lib.cmakeFeature "CMAKE_C_COMPILER" "${stdenv.cc.targetPrefix}cc")
    (lib.cmakeFeature "CMAKE_AR" "${lib.getBin stdenv.cc.bintools.bintools}/bin/${stdenv.cc.targetPrefix}ar")
    (lib.cmakeFeature "CMAKE_RANLIB" "${lib.getBin stdenv.cc.bintools.bintools}/bin/${stdenv.cc.targetPrefix}ranlib")
    (lib.cmakeFeature "CMAKE_STRIP" "${lib.getBin stdenv.cc.bintools.bintools}/bin/${stdenv.cc.targetPrefix}strip")

    (lib.cmakeBool "CMAKE_USE_OPENSSL" false)
    (lib.cmakeBool "BUILD_CursesDialog" false)

    (lib.cmakeBool "BUILD_TESTING" false)
  ];

  dontAddStaticConfigureFlags = true;

  # make install attempts to use the just-built cmake
  preInstall = lib.optionalString (stdenv.hostPlatform != stdenv.buildPlatform) ''
    sed -i 's|bin/cmake|${buildPackages.cmakeMinimal}/bin/cmake|g' Makefile
  '';

  dontUseCmakeConfigure = true;
  enableParallelBuilding = true;

  doCheck = false;

  meta = { };
})
