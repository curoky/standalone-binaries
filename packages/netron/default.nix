# Netron — pure-Python wheel with a relocatable launcher.
#
# Why local:
# 1. A normal Python package entry point records its Nix interpreter and module
#    environment, which does not survive standalone relocation.
# 2. Unpack the pure-Python wheel directly and provide the small console-entry
#    shim ourselves, without adding native extension dependencies.
# 3. Launch with sibling Python 3.14 on Linux or the explicitly supported system
#    `python3` boundary on macOS, using package-relative module paths.
#
# This is intentional runtime packaging, not an upstream build workaround.
{
  lib,
  stdenv,
  fetchurl,
  writeText,
  unzip,
}:

let
  mainPyScript = writeText "main.py" ''
    import re
    import sys

    from netron import main

    if __name__ == "__main__":
        sys.argv[0] = re.sub(r"(-script\.pyw|\.exe)?$", "", sys.argv[0])
        sys.exit(main())
  '';

  wrapperScript = writeText "wrapper.sh" ''
    #!/usr/bin/env bash

    script_path="$(readlink -f "$0")"
    root=$(cd "$(dirname "$script_path")" && pwd)/..
    store=$root/..

    if [[ "$(uname)" == "Darwin" ]]; then
      exec -a "$0" python3 "$root/bin/_netron_main.py" "$@"
    else
      export PYTHONHOME=$store/python314
      export PYTHONPATH=$PYTHONHOME/lib/python3.14
      export PYTHONPATH=$PYTHONPATH:$PYTHONHOME/lib/python3.14/site-packages
      export PYTHONPATH=$PYTHONPATH:$PYTHONHOME/lib/python3.14/lib-dynload
      export PYTHONPATH=$PYTHONPATH:$root/lib/python3.14/site-packages
      exec -a "$0" "$PYTHONHOME/bin/python3.14" "$root/bin/_netron_main.py" "$@"
    fi
  '';
in

stdenv.mkDerivation rec {
  pname = "netron";
  version = "1.0.0";

  src = fetchurl {
    url = "https://files.pythonhosted.org/packages/62/d1/9609fcce7bf2b6d2d2cbc3f13736c2f696d66170c247157e39c7245934b6/netron-9.1.3-py3-none-any.whl";
    sha256 = "sha256-SoTMbCn45cDc5OXIRdxXRzDwhjIaBpa3p9WSpZ3HhkE=";
  };

  unpackPhase = ":";

  nativeBuildInputs = [ unzip ];

  buildPhase = ''
    echo "Unzipping wheel file..."
    mkdir -p wheel-unpacked
    unzip $src -d wheel-unpacked
  '';

  installPhase = ''
    mkdir -p $out/lib/python3.14/site-packages
    cp -r wheel-unpacked/* $out/lib/python3.14/site-packages/

    mkdir -p $out/bin
    cp ${mainPyScript} $out/bin/_netron_main.py
    cp ${wrapperScript} $out/bin/netron
    chmod +x $out/bin/netron
  '';
}
