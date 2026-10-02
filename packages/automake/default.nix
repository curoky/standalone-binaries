# Automake — relocatable Perl modules and macro directories.
#
# Why local:
# 1. Stock Automake builds successfully, but `automake` and `aclocal` retain the
#    Nix output paths of their installed Perl modules and macro directories.
# 2. Those paths are invalid after artifact relocation.
# 3. Keep the real entry points under private names and wrap both commands with
#    paths derived from their own installed location.
#
# This is intentional runtime packaging, not an upstream build workaround.
{
  lib,
  stdenv,
  fetchurl,
  automake,
  writeText,
}:

let
  automake_script = ./scripts;
  automake_version = lib.versions.majorMinor automake.version;
in

automake.overrideAttrs (oldAttrs: {
  postInstall = (oldAttrs.postInstall or "") + ''
    mv $out/bin/automake $out/bin/_automake
    mv $out/bin/aclocal $out/bin/_aclocal

    substitute ${automake_script}/automake $out/bin/automake \
      --replace-fail '@automake_version@' '${automake_version}'
    substitute ${automake_script}/aclocal $out/bin/aclocal \
      --replace-fail '@automake_version@' '${automake_version}'
    chmod +x $out/bin/automake
    chmod +x $out/bin/aclocal
  '';
})
