# 上游包选择。Key 为 nixpkgs attr，可用点访问嵌套属性。
# 省略字段使用默认值；平台配置覆盖包级配置。
#
#   <pkg> = {
#     # 省略 platforms 时启用全部支持平台。
#     platforms = [ "x86_64-linux" "aarch64-darwin" ];
#     version  = "unstable";   # flake.nix 中锁定的 channel 或 pin
#     isStatic = true;         # true 选择 pkgsStatic，false 选择 pkgs
#     output   = [ "out" ];    # 要发布的 derivation outputs
#     alias    = "name";       # 导出名，默认与 key 相同
#     "aarch64-darwin" = { version = "24.11"; };
#   };
{
  ## ---- common (all platforms) -------------------------------------------

  _7zz = {
    alias = "7zz";
    "x86_64-linux" = {
      version = "gcc15-pin";
    };
    "aarch64-linux" = {
      version = "gcc15-pin";
    };
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
  gnupgMinimal = {
    alias = "gnupg";
  };
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
  qpdf = {
    output = [ "bin" ];
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
  fira-code = { };
  lxgw-wenkai = { };
  "nerd-fonts.fira-code" = {
    alias = "nerd-fonts-fira-code";
  };
  "nerd-fonts.ubuntu-mono" = {
    alias = "nerd-fonts-ubuntu-mono";
  };

  # rust pkgs
  atuin = { };
  bat = {
    platforms = [
      "x86_64-linux"
      "aarch64-darwin"
    ];
  };
  dprint = { };
  eza = {
    platforms = [
      "x86_64-linux"
      "aarch64-darwin"
    ];
  };
  fd = { };
  git-absorb = {
    platforms = [
      "x86_64-linux"
      "aarch64-darwin"
    ];
  };
  mcfly = { };
  miniserve = { };
  pnpm = {
    platforms = [ "aarch64-darwin" ];
  };
  procs = { };
  ripgrep = { };
  ruff = { };
  starship = { };
  tokei = { };
  watchexec = { };
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

  catatonit = {
    platforms = [ "x86_64-linux" ];
  };
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
  glibcLocalesUtf8 = {
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    isStatic = false;
    alias = "glibcLocales";
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
  pkgconf = {
    platforms = [ "x86_64-linux" ];
  };
  qemu-user = {
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
  };
  radare2 = {
    platforms = [ "x86_64-linux" ];
    version = "master";
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

  # Versioned Protobuf.
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
    platforms = [ "x86_64-linux" ];
    output = [ "bin" ];
  };
  s6-linux-utils = {
    platforms = [ "x86_64-linux" ];
    output = [ "bin" ];
  };
  s6-networking = {
    platforms = [ "x86_64-linux" ];
    output = [ "bin" ];
  };
  s6-portable-utils = {
    platforms = [ "x86_64-linux" ];
    output = [ "bin" ];
  };
  skalibs = {
    platforms = [ "x86_64-linux" ];
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
      output = [ "bin" ];
    };
  };
  shellcheck = {
    output = [ "bin" ];
    "aarch64-darwin" = {
      version = "25.11";
    };
  };
  uv = { };
}
