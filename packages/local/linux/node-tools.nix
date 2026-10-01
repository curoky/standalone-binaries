{
  pkgs,
  pkgsStatic,
  nodejs-slim26,
}:
{
  prettier = pkgsStatic.callPackage ../../prettier {
    prettier = pkgs.prettier.override { nodejs = nodejs-slim26; };
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
