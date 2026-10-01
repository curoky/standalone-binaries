# manifests/default.nix
#
# Single declarative manifest of upstream nixpkgs packages.
#
# Schema (first-level key = package attr name in nixpkgs):
#
#   <pkg> = {
#     # Optional list of systems this package is built for.
#     # Omitted => all systems (see `allSystems` in make-manifest-packages.nix).
#     platforms = [ "x86_64-linux" "aarch64-darwin" ];
#
#     # Package-level shared config, inherited by every platform:
#     version  = "unstable";   # which pinned nixpkgs env (default "unstable")
#     isStatic = true;         # pkgsStatic (true, default) or pkgs (false)
#     output   = [ "out" ];    # derivation outputs to expose (default [ "out" ])
#     alias    = "name";       # rename exported attribute
#
#     # Per-platform overrides. The effective config for a system is
#     # (package-level shared config) // (platform key config), platform wins.
#     "aarch64-darwin" = { version = "24.11"; };
#   };
{
  ## ---- common (all platforms) -------------------------------------------

  _7zz = {
    alias = "7zz";
    version = "gcc15-pin";
  };
  bash = {
    platforms = [
      "x86_64-linux"
      "aarch64-darwin"
    ];
  };
  "bats.unresholved" = {
    alias = "bats";
  };
  binutils-unwrapped = {
    alias = "binutils";
  };
  bison = { };
  bzip2 = {
    output = [ "bin" ];
  };
  cacert = { };
  connect = { };
  coreutils = {
    platforms = [
      "x86_64-linux"
      "aarch64-darwin"
    ];
  };
  diffutils = {
    platforms = [ "aarch64-darwin" ];
  };
  findutils = { };
  flac = {
    output = [ "bin" ];
  };
  flex = { };
  gawk = { };
  gdb = {
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    version = "25.11";
  };
  gettext = { };
  git-extras = { };
  gnugrep = { };
  gnumake = { };
  gnupatch = { };
  gnused = { };
  gnutar = {
    platforms = [ "aarch64-darwin" ];
  };
  gzip = { };
  inetutils = { };
  jq = {
    output = [ "bin" ];
  };
  less = { };
  libarchive = { };
  lsof = { };
  m4 = { };
  ncdu_1 = { };
  netcat = { };
  ninja = { };
  openssl = {
    output = [ "bin" ];
  };
  patchelf = {
    platforms = [
      "x86_64-linux"
      "aarch64-darwin"
    ];
    "x86_64-linux" = {
      version = "25.05";
    };
  };
  snappy = {
    output = [ "bin" ];
  };
  sqlite = {
    output = [ "bin" ];
  };
  tree = { };
  tzdata = {
    output = [ "out" ];
  };
  unzip = { };
  util-linux = { };
  xxd = { };
  xz = {
    output = [ "bin" ];
  };
  zip = { };
  zlib = {
    output = [ "bin" ];
  };
  zlib-ng = {
    output = [ "bin" ];
  };
  zstd = {
    output = [ "bin" ];
  };

  # fonts
  fira-code = {
    isStatic = false;
  };
  lxgw-wenkai = {
    isStatic = false;
  };
  "nerd-fonts.fira-code" = {
    isStatic = false;
    alias = "nerd-fonts-fira-code";
  };
  "nerd-fonts.ubuntu-mono" = {
    isStatic = false;
    alias = "nerd-fonts-ubuntu-mono";
  };

  # rust pkgs
  atuin = { };
  bat = { };
  dprint = { };
  eza = { };
  fd = { };
  git-absorb = { };
  mcfly = { };
  pnpm = { };
  procs = { };
  ripgrep = { };
  ruff = { };
  starship = { };
  tokei = { };
  yazi-unwrapped = {
    alias = "yazi";
  };
  zellij-unwrapped = {
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    alias = "zellij";
  };

  ## ---- linux only -------------------------------------------------------

  cronie = {
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
  };
  ethtool = {
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
  };
  fuse3 = {
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    output = [ "bin" ];
  };
  indent = {
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
  };
  iproute2 = {
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
  };
  iptables = {
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
  };
  iputils = {
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
  };
  krb5 = {
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
  };
  libcap = {
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
  };
  lsb-release = {
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
  };
  lua5_5 = {
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
  };
  man = {
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
  };
  nettools = {
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
  };
  nil = {
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
  };
  nixfmt = {
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
  };
  numactl = {
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
  };
  procps = {
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
  };
  qemu-user = {
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
  };
  rsync = {
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
  };
  strace = {
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
  };
  tmux = {
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
  };

  # protobuf legacy versions
  protobuf3_8 = {
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    version = "22.11";
    alias = "protobuf_3_8_0";
  };
  protobuf_23 = {
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    version = "24.05";
  };
  protobuf_24 = {
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    version = "25.05";
  };
  protobuf_25 = {
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
  };
  protobuf_26 = {
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    version = "25.05";
  };
  protobuf_27 = {
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
  };
  protobuf_28 = {
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    version = "25.05";
  };
  protobuf_29 = {
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
  };
  protobuf3_20 = {
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    version = "24.05";
  };
  protobuf3_21 = {
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    version = "24.05";
  };

  # s6 stack
  s6-dns = {
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    version = "s6-pin";
    output = [ "bin" ];
  };
  s6-linux-utils = {
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    version = "s6-pin";
    output = [ "bin" ];
  };
  s6-networking = {
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    version = "s6-pin";
    output = [ "bin" ];
  };
  s6-portable-utils = {
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    version = "s6-pin";
    output = [ "bin" ];
  };
  skalibs = {
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    version = "s6-pin";
  };

  # go pkgs
  age = {
    "aarch64-darwin" = {
      isStatic = false;
    };
  };
  sops = {
    "aarch64-darwin" = {
      isStatic = false;
    };
  };
  bazelisk = {
    "aarch64-darwin" = {
      isStatic = false;
    };
  };
  buildifier = {
    "aarch64-darwin" = {
      isStatic = false;
    };
  };
  colima = {
    platforms = [ "aarch64-darwin" ];
    isStatic = false;
  };
  croc = {
    "aarch64-darwin" = {
      isStatic = false;
    };
  };
  docker-compose = {
    "aarch64-darwin" = {
      isStatic = false;
    };
  };
  docker-buildx = {
    "aarch64-darwin" = {
      isStatic = false;
    };
  };
  cmakeMinimal = {
    alias = "cmake";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
  };
  delve = {
    "aarch64-darwin" = {
      isStatic = false;
    };
  };
  dive = {
    platforms = [
      "x86_64-linux"
      "aarch64-darwin"
    ];
    "x86_64-linux" = {
      version = "25.11";
    };
    "aarch64-darwin" = {
      isStatic = false;
    };
  };
  fzf = {
    "aarch64-darwin" = {
      isStatic = false;
    };
  };
  gdu = {
    "aarch64-darwin" = {
      isStatic = false;
    };
  };
  gh = {
    "aarch64-darwin" = {
      isStatic = false;
    };
  };
  git-lfs = {
    "aarch64-darwin" = {
      isStatic = false;
    };
  };
  glab = {
    "aarch64-darwin" = {
      isStatic = false;
    };
  };
  go-task = {
    "aarch64-darwin" = {
      isStatic = false;
    };
  };
  go-tools = {
    "aarch64-darwin" = {
      isStatic = false;
    };
  };
  gofumpt = {
    "aarch64-darwin" = {
      isStatic = false;
    };
  };
  golangci-lint = {
    "aarch64-darwin" = {
      isStatic = false;
    };
  };
  gomodifytags = {
    "aarch64-darwin" = {
      isStatic = false;
    };
  };
  gopls = {
    "aarch64-darwin" = {
      isStatic = false;
    };
  };
  gost = {
    "aarch64-darwin" = {
      isStatic = false;
    };
  };
  gotests = {
    "aarch64-darwin" = {
      isStatic = false;
    };
  };
  gotools = {
    "aarch64-darwin" = {
      isStatic = false;
    };
  };
  impl = {
    "aarch64-darwin" = {
      isStatic = false;
    };
  };
  lefthook = {
    "aarch64-darwin" = {
      isStatic = false;
    };
  };
  lima = {
    platforms = [ "aarch64-darwin" ];
    isStatic = false;
  };
  oras = {
    "aarch64-darwin" = {
      isStatic = false;
    };
  };
  rclone = {
    "aarch64-darwin" = {
      isStatic = false;
    };
  };
  revive = {
    "aarch64-darwin" = {
      isStatic = false;
    };
  };
  runc = {
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
  };
  scc = {
    "aarch64-darwin" = {
      isStatic = false;
    };
  };
  shfmt = {
    "aarch64-darwin" = {
      isStatic = false;
    };
  };
  supercronic = {
    "aarch64-darwin" = {
      isStatic = false;
    };
  };
  lark-cli = {
    "aarch64-darwin" = {
      isStatic = false;
    };
  };

  # llvm pkgs
  lld_18 = {
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
  };
  lld_19 = {
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
  };
  lld_20 = {
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
  };
  lld_21 = {
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
  };
  lld_22 = {
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
  };
  "llvmPackages_18.clang-unwrapped" = {
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    alias = "clang18";
  };
  "llvmPackages_19.clang-unwrapped" = {
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    alias = "clang19";
  };
  "llvmPackages_20.clang-unwrapped" = {
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    alias = "clang20";
  };
  "llvmPackages_21.clang-unwrapped" = {
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    alias = "clang21";
  };
  "llvmPackages_22.clang-unwrapped" = {
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    alias = "clang22";
  };

  ## ---- cross-platform with per-platform overrides -----------------------
  aria2 = {
    "aarch64-darwin" = {
      version = "24.11";
    };
  };
  # shellcheck's executable is in the bin output.
  shellcheck = {
    output = [ "bin" ];
    "aarch64-darwin" = {
      version = "25.11";
    };
  };
  uv = {
    "aarch64-darwin" = {
      version = "25.11";
    };
  };
}
