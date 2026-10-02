# pkgconf — portable default search paths.
#
# Why local:
# 1. Stock `pkgconf-unwrapped` compiles its output's pkg-config, library, include
#    and personality directories into the executable.
# 2. Those `/nix/store` defaults survive artifact assembly and are invalid after
#    relocation.
# 3. Configure pkgconf with the standard `/usr` and `/usr/local` search roots.
#
# Remove this override when stock pkgconf no longer embeds its output path.
{ pkgconf-unwrapped }:

pkgconf-unwrapped.overrideAttrs (oldAttrs: {
  configureFlags = (oldAttrs.configureFlags or [ ]) ++ [
    "--with-pkg-config-dir=/usr/local/lib/pkgconfig:/usr/local/share/pkgconfig:/usr/lib/pkgconfig:/usr/share/pkgconfig"
    "--with-system-libdir=/usr/lib:/lib"
    "--with-system-includedir=/usr/include"
    "--with-personality-dir=/usr/local/share/pkgconfig/personality.d:/usr/share/pkgconfig/personality.d"
  ];
})
