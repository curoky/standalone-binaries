# CMake 4.1.2 — versioned musl-static build.
#
# Why local:
# 1. This exact version is a product output built independently of the moving
#    nixpkgs CMake attribute.
# 2. The test suite links a shared module with the static CRT and fails on a
#    non-PIC relocation, so `BUILD_TESTING` remains disabled.
# 3. OpenSSL, curses and system libraries are excluded deliberately to keep the
#    bootstrap self-contained; those are product choices, not regressions.
#
# Restore tests when they support the static CRT; retain the versioned output
# and reduced dependency policy.
{
  lib,
  stdenv,
  fetchurl,
  buildPackages,
  pkg-config,
}:

# https://github.com/NixOS/nixpkgs/blob/59011787de6d841fcc5e3c0fd7f5d3247ff37a18/pkgs/by-name/cm/cmake/package.nix

stdenv.mkDerivation (finalAttrs: {
  pname = "cmake_4_1_2";
  version = "4.1.2";

  src = fetchurl {
    url = "https://cmake.org/files/v${lib.versions.majorMinor finalAttrs.version}/cmake-${finalAttrs.version}.tar.gz";
    hash = "sha256-ZD8EGCt7oyOrMfUm94UTT7ecujGIqFIgbvBHP+4oKhU=";
  };

  patches = [ ];

  outputs = [ "out" ];

  separateDebugInfo = true;
  setOutputFlags = false;

  setupHooks = [ ];

  depsBuildBuild = [ buildPackages.stdenv.cc ];

  nativeBuildInputs = finalAttrs.setupHooks ++ [
    pkg-config
  ];

  buildInputs = [ ];

  preConfigure = ''
    substituteInPlace Modules/Platform/UnixPaths.cmake \
      --subst-var-by libc_bin ${lib.getBin stdenv.cc.libc} \
      --subst-var-by libc_dev ${lib.getDev stdenv.cc.libc} \
      --subst-var-by libc_lib ${lib.getLib stdenv.cc.libc}
    # CC_FOR_BUILD and CXX_FOR_BUILD are used to bootstrap cmake
    configureFlags="--parallel=''${NIX_BUILD_CORES:-1} CC=$CC_FOR_BUILD CXX=$CXX_FOR_BUILD $configureFlags $cmakeFlags"
  '';

  # The configuration script is not autoconf-based, although being similar;
  # triples and other interesting info are passed via CMAKE_* environment
  # variables and commandline switches
  configurePlatforms = [ ];

  configureFlags = [
    "--docdir=share/doc/${finalAttrs.pname}-${finalAttrs.version}"
    "--no-system-libs"
  ]

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
