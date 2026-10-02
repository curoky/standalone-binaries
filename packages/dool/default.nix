# Dool — script payload with platform runtime selection.
#
# Why local:
# 1. The upstream entry point is tied to the Python interpreter selected inside
#    Nix and is therefore not relocatable as a standalone script package.
# 2. Ship the Python source directly; use sibling Python 3.14 on Linux and the
#    explicitly supported system `python3` boundary on macOS.
# 3. The wrapper also supplies the product default `--bytes` while leaving later
#    user arguments intact.
#
# This is intentional runtime and CLI packaging, not a build workaround.
{
  stdenv,
  writeText,
  dool,
}:

let
  wrapperScript = writeText "wrapper.sh" ''
    #!/usr/bin/env bash

    script_path="$(readlink -f "$0")"
    root=$(cd "$(dirname "$script_path")" && pwd)/..
    store=$root/..

    if [[ "$(uname)" == "Darwin" ]]; then
      exec -a "$0" python3 "$root/bin/_dool_main.py" --bytes "$@"
    else
      export PYTHONHOME=$store/python314
      export PYTHONPATH=$PYTHONHOME/lib/python3.14
      export PYTHONPATH=$PYTHONPATH:$PYTHONHOME/lib/python3.14/site-packages
      export PYTHONPATH=$PYTHONPATH:$PYTHONHOME/lib/python3.14/lib-dynload
      export PYTHONPATH=$PYTHONPATH:$root/lib/python3.14/site-packages
      exec -a "$0" "$PYTHONHOME/bin/python3.14" "$root/bin/_dool_main.py" --bytes "$@"
    fi
  '';
in

stdenv.mkDerivation {
  pname = "dool";
  inherit (dool) version;

  dontUnpack = true;

  installPhase = ''
    mkdir -p $out/bin
    cp ${dool}/bin/dool $out/bin/_dool_main.py
    cp ${wrapperScript} $out/bin/dool
    chmod +x $out/bin/dool
  '';
}
