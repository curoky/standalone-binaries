{
  system,
  pkgs,
  pkgsStatic,
  s6PkgsStatic,
}:
let
  inherit (pkgs) lib;
  mkClangTools = pkgsStatic.callPackage ./clang-tools { };
  mkPython = pkgsStatic.callPackage ./pythonPackages/python { };

  common = {
    # Resource bundles.
    rime-plugins = pkgsStatic.callPackage ./rime-plugins { };
    tmux-plugins = pkgsStatic.callPackage ./tmux-plugins { };
    vim-plugins = pkgs.callPackage ./vim-plugins { };
    zsh-plugins = pkgsStatic.callPackage ./zsh-plugins {
      nativeAtuin = pkgs.atuin;
      nativeStarship = pkgs.starship;
      nativeZsh = pkgs.zsh;
    };

    # C / autotools.
    autoconf = pkgsStatic.callPackage ./autoconf { };
    automake = pkgsStatic.callPackage ./automake { };
    curl = pkgsStatic.callPackage ./curl { };
    eza-ls = pkgsStatic.callPackage ./eza-ls { };
    file = pkgsStatic.callPackage ./file { };
    ghostscript = pkgsStatic.callPackage ./ghostscript { };
    libtool = pkgsStatic.callPackage ./libtool { };
    makeself = pkgsStatic.callPackage ./makeself { };
    pkgconf = pkgsStatic.callPackage ./pkgconf { };
    vim = pkgsStatic.callPackage ./vim { };
    zsh = pkgsStatic.callPackage ./zsh { };

    # Sibling-runtime wrappers.
    git-filter-repo = pkgs.callPackage ./pythonPackages/git-filter-repo.nix { };
    netron = pkgs.callPackage ./pythonPackages/netron.nix { };
    cloc = pkgs.callPackage ./perlPackages/cloc.nix { };
    parallel = pkgs.callPackage ./perlPackages/parallel.nix { };
  };

  linux = rec {
    # Prebuilt glibc-dynamic exception.
    nsight-systems = pkgsStatic.callPackage ./nsight-systems { };

    # C / autotools.
    busybox = pkgsStatic.callPackage ./busybox { };
    cmake_3_27_9 = pkgsStatic.callPackage ./cmake/3_27_9 { };
    cmake_4_1_2 = pkgsStatic.callPackage ./cmake/4_1_2 { };
    diffutils = pkgsStatic.callPackage ./regression/diffutils { };
    ffmpeg = pkgsStatic.callPackage ./ffmpeg/linux.nix { };
    fuse = pkgsStatic.callPackage ./fuse { };
    graphviz = pkgsStatic.callPackage ./graphviz { };
    gnutar = pkgsStatic.callPackage ./regression/gnutar { };
    go = pkgsStatic.callPackage ./go { go = pkgsStatic.go_latest; };
    gocryptfs = pkgsStatic.callPackage ./gocryptfs { };
    lua5_5 = pkgsStatic.callPackage ./lua { };
    openssh_gssapi = pkgsStatic.callPackage ./openssh_gssapi { };
    poppler = pkgsStatic.callPackage ./poppler { };
    postgresql = pkgsStatic.callPackage ./postgresql { };
    protobuf_3_9_2 = pkgsStatic.callPackage ./protobuf/3_9_2 { };
    radare2 = pkgsStatic.callPackage ./regression/radare2 { };
    rizin = pkgsStatic.callPackage ./rizin { };
    shadow = pkgsStatic.callPackage ./shadow {
      inherit (pkgs) symlinkJoin;
    };
    sudo = pkgsStatic.callPackage ./sudo { };
    wget = pkgsStatic.callPackage ./wget/linux.nix { };

    # Rust.
    codex = pkgsStatic.callPackage ./codex { };
    mise = pkgsStatic.callPackage ./mise {
      nativeGit = pkgs.gitMinimal;
    };

    # Perl.
    perl = pkgsStatic.callPackage ./perlPackages/perl/linux.nix { };
    exiftool = pkgs.callPackage ./perlPackages/exiftool/linux.nix { };

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

    # Python.
    python312 = mkPython {
      python = pkgsStatic.python312;
      setupLocal = ./pythonPackages/python/312/Setup.local;
    };
    python313 = mkPython {
      python = pkgsStatic.python313;
      setupLocal = ./pythonPackages/python/313/Setup.local;
    };
    python314 = mkPython {
      python = pkgsStatic.python314;
      setupLocal = ./pythonPackages/python/314/Setup.local;
    };
    python315 = mkPython {
      python = pkgsStatic.python315;
      setupLocal = ./pythonPackages/python/315/Setup.local;
    };
    copyparty = pkgs.callPackage ./pythonPackages/copyparty.nix {
      inherit python314;
    };
    dool = pkgs.callPackage ./pythonPackages/dool.nix { };

    # s6 stack.
    execline = s6PkgsStatic.callPackage ./s6Packages/execline.nix { };
    s6 = s6PkgsStatic.callPackage ./s6Packages/s6.nix {
      inherit execline;
    };
    s6-linux-init = s6PkgsStatic.callPackage ./s6Packages/s6-linux-init.nix {
      inherit s6 execline;
    };
    s6-rc = s6PkgsStatic.callPackage ./s6Packages/s6-rc.nix {
      inherit s6 execline;
    };

    # Podman / container stack.
    catatonit = pkgsStatic.callPackage ./regression/catatonit { };
    conmon = pkgsStatic.callPackage ./regression/conmon { };
    crun = pkgsStatic.callPackage ./crun { };
    gpgme = pkgsStatic.callPackage ./gpgme { };
    aardvark-dns = pkgsStatic.callPackage ./regression/aardvark-dns { };
    podman5 = pkgsStatic.callPackage ./podman/podman5.nix {
      inherit
        catatonit
        crun
        conmon
        gpgme
        aardvark-dns
        ;
    };
    podman6 = pkgsStatic.callPackage ./podman/podman6.nix {
      inherit
        catatonit
        crun
        conmon
        gpgme
        aardvark-dns
        ;
    };
    podman5-rootless = pkgsStatic.callPackage ./podman-rootless { podman = podman5; };
    podman6-rootless = pkgsStatic.callPackage ./podman-rootless { podman = podman6; };

    # Node.js runtime and sibling-runtime tools.
    nodejs-slim24 = pkgsStatic.callPackage ./nodejsPackages/nodejs/24.nix { };
    nodejs-slim26 = pkgsStatic.callPackage ./nodejsPackages/nodejs/26.nix { };
    prettier = pkgsStatic.callPackage ./nodejsPackages/prettier.nix {
      inherit nodejs-slim26;
      inherit (pkgs) prettier;
    };
    markdownlint-cli2 = pkgsStatic.callPackage ./nodejsPackages/markdownlint-cli2.nix {
      inherit nodejs-slim26;
      inherit (pkgs) markdownlint-cli2;
    };
    opencommit = pkgsStatic.callPackage ./nodejsPackages/opencommit.nix {
      inherit nodejs-slim26;
      inherit (pkgs) opencommit;
    };

  };

  darwin = {
    # Partial-static C packages.
    ffmpeg = pkgsStatic.callPackage ./ffmpeg/darwin.nix { };
    krb5 = pkgsStatic.callPackage ./krb5/darwin.nix { };
    poppler = pkgsStatic.callPackage ./poppler { };
    postgresql = pkgsStatic.callPackage ./postgresql/darwin.nix { };
    rsync = pkgsStatic.callPackage ./regression/rsync/darwin.nix {
      inherit (pkgs) libiconv;
      nativeCC = pkgs.stdenv.cc;
    };
    smartmontools = pkgsStatic.callPackage ./smartmontools/darwin.nix {
      inherit (pkgs) autoreconfHook hostname;
    };
    wget = pkgsStatic.callPackage ./wget/darwin-static.nix { };

    # Perl.
    perl = pkgs.callPackage ./perlPackages/perl/darwin.nix {
      libxcryptStatic = pkgsStatic.libxcrypt;
    };
    exiftool = pkgs.callPackage ./perlPackages/exiftool/darwin.nix {
      inherit pkgsStatic;
    };
  };

  x86_64-linux = {
    git = pkgsStatic.callPackage ./git { };
    python311 = mkPython {
      python = pkgsStatic.python311;
      setupLocal = ./pythonPackages/python/311/Setup.local;
    };
  };
in
common
// lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux linux
// lib.optionalAttrs pkgs.stdenv.hostPlatform.isDarwin darwin
// lib.optionalAttrs (system == "x86_64-linux") x86_64-linux
