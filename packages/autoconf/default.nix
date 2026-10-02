# Autoconf — relocatable Perl and M4 resources.
#
# Why local:
# 1. Stock Autoconf builds successfully, but its installed entry points retain
#    the Nix output paths of the Perl modules and M4 data directories.
# 2. Those paths stop resolving after the standalone directory is moved.
# 3. Keep the real scripts under private names and install wrappers that derive
#    every resource directory from their own installed location.
#
# This is intentional runtime packaging, not an upstream build workaround.
{
  lib,
  stdenv,
  fetchurl,
  autoconf,
  writeText,
}:

let
  autoconf_script = ./scripts;
in

autoconf.overrideAttrs (oldAttrs: {
  postInstall = (oldAttrs.postInstall or "") + ''
    mv $out/bin/autoconf $out/bin/_autoconf
    mv $out/bin/autoheader $out/bin/_autoheader
    mv $out/bin/autom4te $out/bin/_autom4te
    mv $out/bin/autoreconf $out/bin/_autoreconf
    mv $out/bin/autoscan $out/bin/_autoscan
    mv $out/bin/autoupdate $out/bin/_autoupdate
    mv $out/bin/ifnames $out/bin/_ifnames

    cp -r ${autoconf_script}/* $out/bin
    chmod +x $out/bin/autoconf
    chmod +x $out/bin/autoheader
    chmod +x $out/bin/autom4te
    chmod +x $out/bin/autoreconf
    chmod +x $out/bin/autoscan
    chmod +x $out/bin/autoupdate
    chmod +x $out/bin/ifnames
  '';
})
