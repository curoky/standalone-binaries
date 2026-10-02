{
  pkgs,
  pkgsStatic,
}:
let
  mkPython = pkgsStatic.callPackage ../../python { };
in
{
  git = pkgsStatic.callPackage ../../git { };
  python311 = mkPython {
    python = pkgsStatic.python311;
    setupLocal = ../../python/311/Setup.local;
  };
}
