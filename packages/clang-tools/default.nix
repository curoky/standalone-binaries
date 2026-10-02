# clang-tools — versioned clang-format-only outputs.
#
# Why local:
# 1. The nixpkgs LLVM package publishes the complete compiler and tool suite,
#    while this product exposes only `clang-format` for each selected major.
# 2. Rebuild clang with size-oriented flags, section garbage collection and
#    mold, then copy only the requested executable into the final output.
# 3. The version is supplied by the caller so multiple LLVM majors can coexist
#    without inheriting the moving default toolchain.
#
# This is intentional output shaping, not an upstream build workaround.
{
  stdenv,
  mold,
}:
{
  llvmPackages,
  version,
}:
let
  clang = llvmPackages.clang-unwrapped.overrideAttrs (oldAttrs: {
    nativeBuildInputs = (oldAttrs.nativeBuildInputs or [ ]) ++ [ mold ];
    env = {
      NIX_CFLAGS_COMPILE =
        (oldAttrs.NIX_CFLAGS_COMPILE or "") + " -g0 -ffunction-sections -fdata-sections";
      NIX_LDFLAGS = (oldAttrs.NIX_LDFLAGS or "") + " --gc-sections -s";
    };

    cmakeFlags = (oldAttrs.cmakeFlags or [ ]) ++ [
      "-DCMAKE_BUILD_TYPE=MinSizeRel"
      "-DLLVM_USE_LINKER=mold"
    ];
  });
in
stdenv.mkDerivation {
  pname = "clang-tools";
  inherit version;

  unpackPhase = ":";
  buildPhase = ":";

  installPhase = ''
    mkdir -p $out/bin
    cp ${clang}/bin/clang-format $out/bin/
  '';
}
