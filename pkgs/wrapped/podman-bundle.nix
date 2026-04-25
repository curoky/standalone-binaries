{
  lib,
  stdenv,
  fetchurl,
  wget,
  podman,
  crun,
  runc,
  aardvark-dns,
  netavark,
  passt,
  conmon,
  catatonit,
  writeText,
}:

let
  wrapperScript = writeText "wrapper.sh" ''
    #!/usr/bin/env bash

    script_path="$(readlink -f "$0")"
    root=$(cd "$(dirname "$script_path")" && pwd)/..

    exec -a "$0" "$root/bin/_wget" --ca-certificate $root/etc/ssl/certs/ca-certificates.crt "$@"
  '';
in

stdenv.mkDerivation rec {
  pname = "podman-bundle";
  version = "1.0.0";

  src = fetchurl {
    url = "https://curl.se/ca/cacert-2024-09-24.pem";
    sha256 = "sha256-GJ089tEDGF+6BtdsGvkVJjxtQiJUgaF1noU7M6yFdUA=";
  };

  unpackPhase = ":";

  nativeBuildInputs = [ podman ];

  installPhase = ''
    mkdir -p $out
    cp -r ${podman}/* $out/
    chmod +w $out/libexec/podman
    cp -r ${crun}/bin/* $out/libexec/podman/
    cp -r ${runc}/bin/* $out/libexec/podman/
    cp -r ${conmon}/bin/* $out/libexec/podman/
    # cp -r ${aardvark-dns}/bin/* $out/libexec/podman/
    # cp -r ${catatonit}/bin/* $out/libexec/podman/
    # cp -r ${netavark}/bin/* $out/libexec/podman/
    # cp -r ${passt}/bin/* $out/libexec/podman/
  '';
}
