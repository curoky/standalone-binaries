{
  pkgs,
  pkgsStatic,
  s6PkgsStatic,
}:
let
  common = import ./common.nix { inherit pkgs pkgsStatic s6PkgsStatic; };
  arch =
    if pkgsStatic.stdenv.hostPlatform.isAarch64 then
      import ./aarch64.nix { inherit pkgs pkgsStatic; }
    else
      import ./x86_64.nix { inherit pkgs pkgsStatic; };
in
common // arch
