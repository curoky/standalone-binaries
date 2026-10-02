# Nsight Systems — vendor glibc binary exception.
#
# Why local:
# 1. NVIDIA publishes this release only as a self-extracting prebuilt Linux
#    distribution; there is no source derivation that can be rebuilt for musl.
# 2. Unpack the vendor installer non-interactively and install its payload
#    without pretending the contained ELF files are static.
# 3. This is the repository's sole approved Linux dynamic-ELF exception; it does
#    not relax the portability gate for any other package.
#
# Replace this package only when NVIDIA provides a usable musl-static release.
{
  lib,
  stdenv,
  fetchurl,
  perl,
}:

stdenv.mkDerivation rec {
  version = "1.0.0";
  pname = "nsight-systems";

  src = fetchurl {
    url = "https://developer.nvidia.com/downloads/assets/tools/secure/nsight-systems/2024_1/nsightsystems-linux-public-2024.1.1.59-3380207.run";
    sha256 = "sha256-XILhK7PisdyVJSowqzoXno+xwGV/tO9COuEnlFzd62A=";
  };

  nativeBuildInputs = [ perl ];
  unpackPhase = ''
    cp $src nsightsystems_linux.run
  '';
  installPhase = ''
    chmod +x nsightsystems_linux.run
    sed -i 's|/dev/tty|/dev/null|' nsightsystems_linux.run
    ./nsightsystems_linux.run --accept --noexec --target . || echo ignore
    perl ./install-linux.pl -targetpath=$out -noprompt
    rm -rf nsightsystems_linux.run
  '';

  meta = with lib; {
    description = "nsight-systems";
  };
}
