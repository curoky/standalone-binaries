# x86_64-linux-only local packages.
{
  pkgs,
  pkgsStatic,
}:
let
  mkPython = pkgsStatic.callPackage ../../python { };
in
{
  python311 = mkPython {
    python = pkgsStatic.python311;
    setupLocal = ../../python/311/Setup.local;
  };
}
