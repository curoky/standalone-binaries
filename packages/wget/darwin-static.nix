# wget for macOS — partial-static binary with relocatable certificates.
#
# Why local:
# 1. Darwin `pkgsStatic.perl` crashes while its `mktables` step generates Unicode
#    tables, so stock static wget cannot finish building its build-time Perl.
#    Wget uses Perl only during the build; inject native Perl while keeping all
#    wget target libraries static.
# 2. A standalone wget cannot rely on a Nix CA path. Bundle cacert and use a
#    wrapper that resolves it relative to the executable.
#
# Regress the native build-tool override when static Perl works; retain the
# certificate packaging.
{
  stdenv,
  wget,
  cacert,
  perlPackages,
  writeText,
}:

let
  wget_static = wget.override {
    inherit perlPackages;
  };

  wrapperScript = writeText "wrapper.sh" ''
    #!/usr/bin/env bash

    script_path="$(readlink -f "$0")"
    root=$(cd "$(dirname "$script_path")" && pwd)/..

    exec -a "$0" "$root/bin/_wget" --ca-certificate $root/etc/wget/ca-bundle.crt "$@"
  '';
in

stdenv.mkDerivation rec {
  pname = "wget";
  version = "1.0.0";

  dontUnpack = true;

  installPhase = ''
    mkdir -p $out
    cp -r ${wget_static}/bin $out/bin
    cp -r ${wget_static}/etc $out/etc

    chmod +w $out/etc/
    mkdir -p $out/etc/wget/
    cp ${cacert}/etc/ssl/certs/ca-bundle.crt $out/etc/wget/ca-bundle.crt

    chmod +w $out/bin/
    mv $out/bin/wget $out/bin/_wget
    cp ${wrapperScript} $out/bin/wget
    chmod +x $out/bin/wget
  '';
}
