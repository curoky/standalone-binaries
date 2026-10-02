{
  pkgs,
  pkgsStatic,
  nodejs-slim26,
}:
{
  prettier = pkgsStatic.callPackage ../../prettier {
    inherit nodejs-slim26;
    inherit (pkgs) prettier;
  };
  markdownlint-cli2 = pkgsStatic.callPackage ../../markdownlint-cli2 {
    inherit nodejs-slim26;
    inherit (pkgs) markdownlint-cli2;
  };
  opencommit = pkgsStatic.callPackage ../../opencommit {
    inherit nodejs-slim26;
    inherit (pkgs) opencommit;
  };
}
