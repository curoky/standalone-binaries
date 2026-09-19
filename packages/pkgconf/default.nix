# pkgconf — no Nix store paths baked into the binary.
#
# Stock `pkgconf-unwrapped` compiles its own Nix output's `.pc`, system
# lib/include and personality paths into the binary. Point them at the standard
# `/usr` and `/usr/local` locations so the standalone product has no
# `/nix/store` residue.
{ pkgconf-unwrapped }:

pkgconf-unwrapped.overrideAttrs (oldAttrs: {
  configureFlags = (oldAttrs.configureFlags or [ ]) ++ [
    "--with-pkg-config-dir=/usr/local/lib/pkgconfig:/usr/local/share/pkgconfig:/usr/lib/pkgconfig:/usr/share/pkgconfig"
    "--with-system-libdir=/usr/lib:/lib"
    "--with-system-includedir=/usr/include"
    "--with-personality-dir=/usr/local/share/pkgconfig/personality.d:/usr/share/pkgconfig/personality.d"
  ];
})
