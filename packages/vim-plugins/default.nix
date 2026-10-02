# Vim plugins — curated runtime bundle.
#
# Why local:
# 1. Consumers expect one fixed `vim-plugin` tree rather than independently
#    installed nixpkgs plugin outputs.
# 2. Install vim-plug in `autoload` and copy the selected plugins beneath the
#    matching `plugged` layout.
# 3. The bundle contains only data and Vim scripts; it has no static-linking
#    requirement beyond remaining free of Nix store references.
#
# This is a product data bundle, not an upstream workaround.
{
  lib,
  stdenv,
  vimPlugins,
}:

let
  inherit (vimPlugins) vim-plug;
  inherit (vimPlugins) vim-airline;
  inherit (vimPlugins) vim-airline-themes;
  inherit (vimPlugins) vim-colors-solarized;
  inherit (vimPlugins) indentLine;
  inherit (vimPlugins) vim-gitgutter;
  inherit (vimPlugins) nerdtree;
  inherit (vimPlugins) nerdtree-git-plugin;
in

stdenv.mkDerivation rec {
  pname = "vim-plugins";
  version = "1.0.0";

  nativeBuildInputs = [ ];

  unpackPhase = ":";

  buildPhase = ":";

  installPhase = ''
    mkdir -p $out/share/
    mkdir -p $out/share/vim-plugin/autoload
    cp ${vim-plug.src}/plug.vim $out/share/vim-plugin/autoload/
    mkdir -p $out/share/vim-plugin/plugged
    cp -r ${vim-airline}/ $out/share/vim-plugin/plugged/vim-airline
    cp -r ${vim-airline-themes}/ $out/share/vim-plugin/plugged/vim-airline-themes
    cp -r ${vim-colors-solarized}/ $out/share/vim-plugin/plugged/vim-colors-solarized
    cp -r ${indentLine}/ $out/share/vim-plugin/plugged/indentLine
    cp -r ${vim-gitgutter}/ $out/share/vim-plugin/plugged/vim-gitgutter
    cp -r ${nerdtree}/ $out/share/vim-plugin/plugged/nerdtree
    cp -r ${nerdtree-git-plugin}/ $out/share/vim-plugin/plugged/nerdtree-git-plugin
  '';

  meta = with lib; {
    description = "vim bundle";
  };
}
