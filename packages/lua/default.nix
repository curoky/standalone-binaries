# lua5.5 — portable module search paths.
#
# Why local:
# 1. Nixpkgs substitutes the output prefix into Lua's compiled default module
#    paths.
# 2. Those paths become invalid when the standalone artifact is relocated.
# 3. Restore upstream's conventional `/usr/local` prefix in `luaconf.h`.
#
# Remove this override when stock Lua no longer embeds its Nix output path.
{ lua5_5 }:

lua5_5.overrideAttrs (oldAttrs: {
  postPatch = (oldAttrs.postPatch or "") + ''
    substituteInPlace src/luaconf.h \
      --replace-fail "$out/" "/usr/local/"
  '';
})
