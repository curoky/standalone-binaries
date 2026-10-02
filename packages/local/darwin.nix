{
  pkgs,
  pkgsStatic,
}:
{
  # Partial-static C packages.
  ffmpeg = pkgsStatic.callPackage ../ffmpeg/darwin.nix { };
  krb5 = pkgsStatic.callPackage ../krb5/darwin.nix { };
  poppler = pkgsStatic.callPackage ../poppler { nativePython3 = pkgs.python3; };
  postgresql = pkgsStatic.callPackage ../postgresql/darwin.nix { };
  rsync = pkgsStatic.callPackage ../rsync/darwin.nix {
    inherit (pkgs) python3 libiconv;
    nativeCC = pkgs.stdenv.cc;
  };
  smartmontools = pkgsStatic.callPackage ../smartmontools/darwin.nix {
    inherit (pkgs) autoreconfHook hostname;
  };
  wget = pkgsStatic.callPackage ../wget/darwin-static.nix {
    inherit (pkgs) perlPackages;
  };

  # Perl.
  perl = pkgs.callPackage ../perl/darwin.nix {
    libxcryptStatic = pkgsStatic.libxcrypt;
  };
  exiftool = pkgs.callPackage ../exiftool/darwin.nix {
    inherit pkgsStatic;
  };
}
