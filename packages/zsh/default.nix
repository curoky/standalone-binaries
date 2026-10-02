# Zsh — static modules with relocatable runtime data.
#
# Why local:
# 1. Stock static Zsh leaves system, regex and mathfunc as loadable modules.
#    A static executable cannot load them, so `zmodload` fails; mark all three
#    `link=either` so they are built into the executable.
# 2. Nixpkgs configures the global zshenv under the immutable output. Point it
#    at `/etc/zsh/zshenv`, the host-controlled system configuration path.
# 3. Shell functions live inside the moved package. The wrapper derives FPATH
#    from its own location instead of retaining an output path.
#
# Regress only the module change when stock static Zsh embeds them; retain the
# zshenv and FPATH packaging policy.
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
  configureFlags =
    (lib.filter (f: !(lib.hasPrefix "--enable-zshenv=" f)) (oldAttrs.configureFlags or [ ]))
    ++ [ "--enable-zshenv=/etc/zsh/zshenv" ];

  postPatch = (oldAttrs.postPatch or "") + ''
    echo "link=either" >> Src/Modules/system.mdd
    echo "link=either" >> Src/Modules/regex.mdd
    echo "link=either" >> Src/Modules/mathfunc.mdd
  '';

  outputs = [
    "out"
    "man"
  ];

  postInstall = ''
    mv $out/bin/zsh $out/bin/_zsh
    cp ${wrapperScript} $out/bin/zsh
    chmod +x $out/bin/zsh
  '';
})
