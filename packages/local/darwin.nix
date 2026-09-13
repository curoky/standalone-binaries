{
  pkgs,
  pkgsStatic,
}:
let
  nodejs-slim26 = pkgsStatic.callPackage ../nodejs/26/darwin.nix {
    inherit (pkgs) python3 cctools;
  };
  nodeTools = import ./node-tools.nix {
    inherit pkgs pkgsStatic nodejs-slim26;
  };
in
{
  # colima binary only; runtime deps (lima, docker, ...) are installed
  # separately. Artifact normalizes eligible native CGO resolver dependencies.
  colima = pkgs.callPackage ../colima { };

  # lima: hostside limactl + helpers + bundled guest agents. qemu PATH wrapper
  # dropped (darwin defaults to the VZ backend); runtime deps installed
  # separately. Artifact preserves entitlements during CGO resolver relocation.
  lima = pkgs.callPackage ../lima { };

  # Partial-static C packages.
  ffmpeg = pkgsStatic.callPackage ../ffmpeg/darwin.nix { };
  krb5 = pkgsStatic.callPackage ../krb5/darwin.nix { };
  rsync = pkgsStatic.callPackage ../rsync/darwin.nix {
    inherit (pkgs) python3 libiconv;
    nativeCC = pkgs.stdenv.cc;
  };
  wget = pkgsStatic.callPackage ../wget/darwin-static.nix {
    inherit (pkgs) perlPackages;
  };

  # rclone must relocate libresolv before its package-specific nuke-refs.
  rclone = pkgs.callPackage ../rclone/darwin.nix { };

  # Perl.
  perl = pkgs.callPackage ../perl/darwin.nix {
    libxcryptStatic = pkgsStatic.libxcrypt;
  };
  exiftool = pkgs.callPackage ../exiftool/darwin.nix {
    inherit pkgsStatic;
  };

  # Node.js runtime and sibling-runtime tools.
  inherit nodejs-slim26;
  inherit (nodeTools)
    markdownlint-cli2
    opencommit
    pnpm
    prettier
    ;
}
