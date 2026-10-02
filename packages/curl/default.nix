# curl — bundled, relocatable CA certificates.
#
# Why local:
# 1. Stock curl builds successfully, but its TLS verification depends on a host
#    CA location or on the Nix store path of the certificate package.
# 2. A moved artifact can assume neither path exists.
# 3. Copy the CA bundle into the package and wrap curl with a `--cacert` path
#    derived from the executable's installed location.
#
# This is permanent standalone packaging, not an upstream build workaround.
{
  lib,
  stdenv,
  curl,
  cacert,
  writeText,
}:

let
  wrapperScript = writeText "wrapper.sh" ''
    #!/usr/bin/env bash

    script_path="$(readlink -f "$0")"
    root=$(cd "$(dirname "$script_path")" && pwd)/..

    exec -a "$0" "$root/bin/_curl" --cacert $root/etc/curl/ca-bundle.crt "$@"
  '';
in

stdenv.mkDerivation rec {
  pname = "curl";
  version = "1.0.0";

  dontUnpack = true;

  nativeBuildInputs = [ curl ];

  installPhase = ''
    mkdir -p $out
    cp -r ${curl.bin}/bin/ $out/bin
    cp -r ${curl.dev}/share $out/share

    mkdir -p $out/etc/curl/
    cp ${cacert}/etc/ssl/certs/ca-bundle.crt $out/etc/curl/ca-bundle.crt

    chmod +w $out/bin/
    mv $out/bin/curl $out/bin/_curl
    cp ${wrapperScript} $out/bin/curl
    chmod +x $out/bin/curl
  '';
}
