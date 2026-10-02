# libtool — relocatable libtoolize resources.
#
# Why local:
# 1. Stock libtool builds successfully, but `libtoolize` records its helper,
#    macro and data directories under the Nix output prefix.
# 2. Those paths are invalid once the artifact is moved.
# 3. Rewrite only the installed shell variables so all three resource classes
#    resolve from `libtoolize`'s own installed location.
#
# This is permanent runtime packaging, not an upstream build workaround.
{
  lib,
  stdenv,
  fetchurl,
  libtool,
  writeText,
}:

libtool.overrideAttrs (oldAttrs: {
  postInstall = (oldAttrs.postInstall or "") + ''
    sed -i 's| prefix=| script_path="$(readlink -f "$0")" #|g' $out/bin/libtoolize
    sed -i 's| datadir=| root=$(cd "$(dirname "$script_path")" \&\& pwd)/.. #|g' $out/bin/libtoolize
    sed -i 's| pkgauxdir=| pkgauxdir=$root/share/libtool/build-aux #|g' $out/bin/libtoolize
    sed -i 's| pkgltdldir=| pkgltdldir=$root/share/libtool #|g' $out/bin/libtoolize
    sed -i 's| aclocaldir=| aclocaldir=$root/share/aclocal #|g' $out/bin/libtoolize
  '';
})
