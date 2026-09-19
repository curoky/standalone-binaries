# zsh — musl-static build with three modules built in, plus an FPATH wrapper.
#
# Without the `link=either` patch the static build fails to `zmodload
# zsh/system`, `zsh/regex` and `zsh/mathfunc`, so those three modules must be
# built in. The wrapper resolves the co-located functions dir relative to the
# install (FPATH) and `--enable-zshenv=/etc/zsh/zshenv` keeps the global zshenv
# out of the read-only store (packaging policy).
{
  lib,
  stdenv,
  fetchurl,
  zsh,
  writeText,
}:

let
  wrapperScript = writeText "wrapper.sh" ''
    #!/usr/bin/env bash

    script_path="$(readlink -f "$0")"
    root=$(cd "$(dirname "$script_path")" && pwd)/..
    export FPATH=$FPATH:$root/share/zsh/${zsh.version}/functions

    exec -a "$0" "$root/bin/_zsh" "$@"
  '';
in

zsh.overrideAttrs (oldAttrs: rec {
  # nixpkgs sets `--enable-zshenv=$out/etc/zshenv`, pinning the global zshenv
  # into the read-only Nix store. Drop that flag and point it at /etc/zsh/zshenv
  # so a system-wide /etc/zsh/zshenv is honored.
  configureFlags =
    (lib.filter (f: !(lib.hasPrefix "--enable-zshenv=" f)) (oldAttrs.configureFlags or [ ]))
    ++ [ "--enable-zshenv=/etc/zsh/zshenv" ];

  # Force the system/regex/mathfunc modules to be buildable either statically
  # or dynamically; the static build otherwise fails to `zmodload` all three.
  postPatch = (oldAttrs.postPatch or "") + ''
    echo "link=either" >> Src/Modules/system.mdd
    echo "link=either" >> Src/Modules/regex.mdd
    echo "link=either" >> Src/Modules/mathfunc.mdd
  '';

  outputs = [
    "out"
    "man"
  ];

  # nativeBuildInputs = builtins.filter (dep: dep.pname or "" != "yodl") oldAttrs.nativeBuildInputs;

  # postInstall = (oldAttrs.postInstall or "") + ''
  postInstall = ''
    mv $out/bin/zsh $out/bin/_zsh
    cp ${wrapperScript} $out/bin/zsh
    chmod +x $out/bin/zsh
  '';
})
