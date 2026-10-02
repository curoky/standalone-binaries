{
  pkgs,
  pkgsStatic,
  s6PkgsStatic,
}:
{
  common = import ./local/common.nix {
    inherit pkgs pkgsStatic;
  };
  linux = import ./local/linux {
    inherit pkgs pkgsStatic s6PkgsStatic;
  };
  darwin = import ./local/darwin.nix {
    inherit pkgs pkgsStatic;
  };
}
