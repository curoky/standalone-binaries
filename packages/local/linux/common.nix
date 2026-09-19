{
  pkgs,
  pkgsStatic,
  s6PkgsStatic,
}:
let
  mkClangTools = pkgsStatic.callPackage ../../clang-tools { };
  mkPython = pkgsStatic.callPackage ../../python { };
  nodejs-slim26 = pkgsStatic.callPackage ../../nodejs/26/linux.nix {
    inherit (pkgs) python3;
  };
  nodeTools = import ../node-tools.nix {
    inherit pkgs pkgsStatic nodejs-slim26;
  };
in
rec {
  # Prebuilt glibc-dynamic exception.
  nsight-systems = pkgsStatic.callPackage ../../nsight-systems { };

  # C / autotools.
  cmake_3_27_9 = pkgsStatic.callPackage ../../cmake/3_27_9 { };
  cmake_4_1_2 = pkgsStatic.callPackage ../../cmake/4_1_2 { };
  diffutils = pkgsStatic.callPackage ../../diffutils { };
  fuse = pkgsStatic.callPackage ../../fuse { };
  git = pkgsStatic.callPackage ../../git { };
  graphviz = pkgsStatic.callPackage ../../graphviz {
    inherit (pkgs) python3;
  };
  gnutar = pkgsStatic.callPackage ../../gnutar { };
  gocryptfs = pkgsStatic.callPackage ../../gocryptfs { };
  libarchive = pkgsStatic.callPackage ../../libarchive { };
  lua5_5 = pkgsStatic.callPackage ../../lua { };
  openssh_gssapi = pkgsStatic.callPackage ../../openssh_gssapi { };
  poppler = pkgsStatic.callPackage ../../poppler { };
  postgresql = pkgsStatic.callPackage ../../postgresql { };
  sudo = pkgsStatic.callPackage ../../sudo { };
  wget = pkgsStatic.callPackage ../../wget/linux.nix { };

  # Rust.
  miniserve = pkgsStatic.callPackage ../../miniserve { };
  zellij = pkgsStatic.callPackage ../../zellij { };

  # Perl.
  perl = pkgsStatic.callPackage ../../perl/linux.nix { };
  exiftool = pkgs.callPackage ../../exiftool/linux.nix { };

  # LLVM / clang tooling.
  clang-tools-18 = mkClangTools {
    llvmPackages = pkgsStatic.llvmPackages_18;
    version = "18.0.0";
  };
  clang-tools-19 = mkClangTools {
    llvmPackages = pkgsStatic.llvmPackages_19;
    version = "19.0.0";
  };
  clang-tools-20 = mkClangTools {
    llvmPackages = pkgsStatic.llvmPackages_20;
    version = "20.0.0";
  };
  clang-tools-21 = mkClangTools {
    llvmPackages = pkgsStatic.llvmPackages_21;
    version = "21.0.0";
  };
  clang-tools-22 = mkClangTools {
    llvmPackages = pkgsStatic.llvmPackages_22;
    version = "22.0.0";
  };

  # Python. python311 is x86_64-only; see ./x86_64.nix.
  python312 = mkPython {
    python = pkgsStatic.python312;
    setupLocal = ../../python/312/Setup.local;
  };
  python313 = mkPython {
    python = pkgsStatic.python313;
    setupLocal = ../../python/313/Setup.local;
  };
  python314 = mkPython {
    python = pkgsStatic.python314;
    setupLocal = ../../python/314/Setup.local;
  };
  python315 = mkPython {
    python = pkgsStatic.python315;
    setupLocal = ../../python/315/Setup.local;
  };
  copyparty = pkgs.callPackage ../../copyparty {
    inherit python314;
  };
  dool = pkgs.callPackage ../../dool { };

  # s6 stack. Built against s6PkgsStatic (a pinned static set) instead of
  # unstable; see flake.nix (nixpkgs-s6) for why.
  execline = s6PkgsStatic.callPackage ../../execline { };
  s6 = s6PkgsStatic.callPackage ../../s6 {
    inherit execline;
  };
  s6-linux-init = s6PkgsStatic.callPackage ../../s6-linux-init {
    inherit s6 execline;
  };
  s6-rc = s6PkgsStatic.callPackage ../../s6-rc {
    inherit s6 execline;
  };

  # Podman / container stack.
  catatonit = pkgsStatic.callPackage ../../catatonit { };
  conmon = pkgsStatic.callPackage ../../conmon { };
  crun = pkgsStatic.callPackage ../../crun { };
  gpgme = pkgsStatic.callPackage ../../gpgme { };
  aardvark-dns = pkgsStatic.callPackage ../../aardvark-dns { };
  podman5 = pkgsStatic.callPackage ../../podman/podman5.nix {
    inherit
      catatonit
      crun
      conmon
      gpgme
      aardvark-dns
      ;
  };
  podman6 = pkgsStatic.callPackage ../../podman/podman6.nix {
    inherit
      catatonit
      crun
      conmon
      gpgme
      aardvark-dns
      ;
  };

  # Node.js runtime and sibling-runtime tools; see
  # docs/package-strategies/nodejs.md.
  nodejs-slim24 = pkgsStatic.callPackage ../../nodejs/24 {
    inherit (pkgs) python3;
  };
  inherit nodejs-slim26;
  inherit (nodeTools)
    markdownlint-cli2
    opencommit
    pnpm
    prettier
    ;

  # Native glibc data.
  glibcLocales = pkgs.glibcLocales.override {
    allLocales = false;
  };
}
