# Package support

本表按软件自身支持范围和仓库明确的产品族平台边界分组，并列出当前的平台接线。单纯构建
失败或尚未接入只在对应平台标为 `—`，不改变分组，也不表示最新 CI 或远端发布状态。
macOS 仅支持 Apple Silicon；具体发布策略见[发布模型](release-model.md)。

- ✅：直接使用上游包；`binman`、`nixcache` 是本仓库独立构建的工具。
- 🩹：有包级本地定制，包括 patch、override、wrapper、资源打包或裁剪。
- 📌：选择非默认 nixpkgs channel。
- —：未接入该平台。

共用 build-tool 和 artifact 处理不逐包标记。同级 runtime 需要分别安装，见
[安装说明](../cmd/binman/USAGE.md)。`nsight-systems` 使用宿主 glibc；Darwin Rclone
有已知资源路径缺口，详见[产物边界](package-strategies/special-cases.md)。

## Cross-platform

| Package | Linux x86_64 | Linux ARM64 | macOS ARM64 |
| --- | :---: | :---: | :---: |
| `7zz` | ✅ 📌 | ✅ 📌 | ✅ |
| `age` | ✅ | ✅ | ✅ |
| `aria2` | ✅ | ✅ | ✅ 📌 |
| `atuin` | ✅ | ✅ | ✅ |
| `autoconf` | 🩹 | — | 🩹 |
| `automake` | 🩹 | — | 🩹 |
| `bash` | ✅ | — | ✅ |
| `bat` | ✅ | — | ✅ |
| `bats` | ✅ | ✅ | ✅ |
| `bazelisk` | ✅ | ✅ | ✅ |
| `binman` | ✅ | ✅ | ✅ |
| `binutils` | ✅ | ✅ | ✅ |
| `bison` | ✅ | ✅ | ✅ |
| `buildifier` | ✅ | ✅ | ✅ |
| `bzip2` | ✅ | ✅ | ✅ |
| `cacert` | ✅ | ✅ | ✅ |
| `cloc` | 🩹 | — | 🩹 |
| `cmake` | ✅ | ✅ | — |
| `cmake_3_27_9` | 🩹 | — | — |
| `cmake_4_1_2` | 🩹 | — | — |
| `codex` | 🩹 | — | — |
| `connect` | ✅ | ✅ | ✅ |
| `coreutils` | ✅ | — | ✅ |
| `croc` | ✅ | ✅ | ✅ |
| `curl` | 🩹 | — | 🩹 |
| `delve` | ✅ | ✅ | ✅ |
| `diffutils` | 🩹 | — | ✅ |
| `dive` | ✅ | — | ✅ |
| `docker-buildx` | ✅ | ✅ | ✅ |
| `docker-compose` | ✅ | ✅ | ✅ |
| `dprint` | ✅ | ✅ | ✅ |
| `exiftool` | 🩹 | — | 🩹 |
| `eza` | ✅ | — | ✅ |
| `eza-ls` | 🩹 | — | 🩹 |
| `fd` | ✅ | ✅ | ✅ |
| `ffmpeg` | 🩹 | — | 🩹 |
| `file` | 🩹 | — | 🩹 |
| `findutils` | ✅ | ✅ | ✅ |
| `fira-code` | ✅ | ✅ | ✅ |
| `flac` | ✅ | ✅ | ✅ |
| `flex` | ✅ | ✅ | ✅ |
| `fzf` | ✅ | ✅ | ✅ |
| `gawk` | ✅ | ✅ | ✅ |
| `gdb` | ✅ 📌 | ✅ 📌 | — |
| `gdu` | ✅ | ✅ | ✅ |
| `gettext` | ✅ | ✅ | ✅ |
| `gh` | ✅ | ✅ | ✅ |
| `ghostscript` | 🩹 | — | 🩹 |
| `git` | 🩹 | — | — |
| `git-absorb` | ✅ | — | ✅ |
| `git-extras` | ✅ | ✅ | ✅ |
| `git-filter-repo` | 🩹 | — | 🩹 |
| `git-lfs` | ✅ | ✅ | ✅ |
| `glab` | ✅ | ✅ | ✅ |
| `gnugrep` | ✅ | ✅ | ✅ |
| `gnumake` | ✅ | ✅ | ✅ |
| `gnupatch` | ✅ | ✅ | ✅ |
| `gnupg` | ✅ | ✅ | ✅ |
| `gnused` | ✅ | ✅ | ✅ |
| `gnutar` | 🩹 | — | ✅ |
| `go` | 🩹 | — | — |
| `go-task` | ✅ | ✅ | ✅ |
| `go-tools` | ✅ | ✅ | ✅ |
| `gocryptfs` | 🩹 | — | — |
| `gofumpt` | ✅ | ✅ | ✅ |
| `golangci-lint` | ✅ | ✅ | ✅ |
| `gomodifytags` | ✅ | ✅ | ✅ |
| `gopls` | ✅ | ✅ | ✅ |
| `gost` | ✅ | ✅ | ✅ |
| `gotests` | ✅ | ✅ | ✅ |
| `gotools` | ✅ | ✅ | ✅ |
| `graphviz` | 🩹 | — | — |
| `gzip` | ✅ | ✅ | ✅ |
| `imagemagick` | 🩹 | — | 🩹 |
| `impl` | ✅ | ✅ | ✅ |
| `indent` | ✅ | ✅ | — |
| `inetutils` | ✅ | ✅ | ✅ |
| `jq` | ✅ | ✅ | ✅ |
| `krb5` | ✅ | ✅ | 🩹 |
| `lark-cli` | ✅ | ✅ | ✅ |
| `lefthook` | ✅ | ✅ | ✅ |
| `less` | ✅ | ✅ | ✅ |
| `libarchive` | ✅ | ✅ | ✅ |
| `libtool` | 🩹 | — | 🩹 |
| `lsof` | ✅ | ✅ | ✅ |
| `lua5_5` | ✅ | ✅ | — |
| `lxgw-wenkai` | ✅ | ✅ | ✅ |
| `m4` | ✅ | ✅ | ✅ |
| `makeself` | 🩹 | — | 🩹 |
| `man` | ✅ | ✅ | — |
| `mcfly` | ✅ | ✅ | ✅ |
| `miniserve` | ✅ | ✅ | ✅ |
| `mise` | 🩹 | — | — |
| `ncdu_1` | ✅ | ✅ | ✅ |
| `nerd-fonts-fira-code` | ✅ | ✅ | ✅ |
| `nerd-fonts-ubuntu-mono` | ✅ | ✅ | ✅ |
| `netcat` | ✅ | ✅ | ✅ |
| `netron` | 🩹 | — | 🩹 |
| `nil` | ✅ | ✅ | — |
| `ninja` | ✅ | ✅ | ✅ |
| `nixcache` | ✅ | ✅ | ✅ |
| `nixfmt` | ✅ | ✅ | — |
| `openssh_gssapi` | 🩹 | — | — |
| `openssl` | ✅ | ✅ | ✅ |
| `oras` | ✅ | ✅ | ✅ |
| `parallel` | 🩹 | — | 🩹 |
| `patchelf` | ✅ 📌 | — | ✅ |
| `perl` | 🩹 | — | 🩹 |
| `pkgconf` | ✅ | — | 🩹 |
| `pnpm` | 🩹 | — | ✅ |
| `poppler` | 🩹 | — | 🩹 |
| `postgresql` | 🩹 | — | 🩹 |
| `procs` | ✅ | ✅ | ✅ |
| `qpdf` | ✅ | ✅ | ✅ |
| `radare2` | ✅ 📌 | — | — |
| `rclone` | ✅ | ✅ | ✅ |
| `revive` | ✅ | ✅ | ✅ |
| `rime-plugins` | 🩹 | — | 🩹 |
| `ripgrep` | ✅ | ✅ | ✅ |
| `rizin` | 🩹 | — | — |
| `rsync` | ✅ | ✅ | 🩹 |
| `ruff` | ✅ | ✅ | ✅ |
| `scc` | ✅ | ✅ | ✅ |
| `shellcheck` | ✅ | ✅ | ✅ 📌 |
| `shfmt` | ✅ | ✅ | ✅ |
| `smartmontools` | — | — | 🩹 |
| `sops` | ✅ | ✅ | ✅ |
| `sqlite` | ✅ | ✅ | ✅ |
| `starship` | ✅ | ✅ | ✅ |
| `sudo` | 🩹 | — | — |
| `supercronic` | ✅ | ✅ | ✅ |
| `tesseract` | 🩹 | — | 🩹 |
| `tmux` | ✅ | ✅ | — |
| `tmux-plugins` | 🩹 | — | 🩹 |
| `tokei` | ✅ | ✅ | ✅ |
| `tree` | ✅ | ✅ | ✅ |
| `tzdata` | ✅ | ✅ | ✅ |
| `unzip` | ✅ | ✅ | ✅ |
| `util-linux` | ✅ | ✅ | ✅ |
| `uv` | ✅ | ✅ | ✅ |
| `vim` | 🩹 | — | 🩹 |
| `vim-plugins` | 🩹 | — | 🩹 |
| `watchexec` | ✅ | ✅ | ✅ |
| `wget` | 🩹 | — | 🩹 |
| `xxd` | ✅ | ✅ | ✅ |
| `xz` | ✅ | ✅ | ✅ |
| `yazi` | ✅ | ✅ | ✅ |
| `zellij` | ✅ | ✅ | — |
| `zip` | ✅ | ✅ | ✅ |
| `zsh` | 🩹 | — | 🩹 |
| `zsh-plugins` | 🩹 | — | 🩹 |
| `zstd` | ✅ | ✅ | ✅ |

## Linux only

| Package | Linux x86_64 | Linux ARM64 |
| --- | :---: | :---: |
| `buildah` | 🩹 | — |
| `busybox` | 🩹 | — |
| `clang-tools-18` | 🩹 | — |
| `clang-tools-19` | 🩹 | — |
| `clang-tools-20` | 🩹 | — |
| `clang-tools-21` | 🩹 | — |
| `clang-tools-22` | 🩹 | — |
| `clang-tools-23` | 🩹 | — |
| `clang18` | ✅ | ✅ |
| `clang19` | ✅ | ✅ |
| `clang20` | ✅ | ✅ |
| `clang21` | ✅ | ✅ |
| `clang22` | ✅ | ✅ |
| `copyparty` | 🩹 | — |
| `cronie` | ✅ | ✅ |
| `dool` | 🩹 | — |
| `ethtool` | ✅ | ✅ |
| `execline` | 🩹 | — |
| `fuse` | 🩹 | — |
| `fuse3` | ✅ | ✅ |
| `glibcLocales` | ✅ | ✅ |
| `iproute2` | ✅ | ✅ |
| `iptables` | ✅ | ✅ |
| `iputils` | ✅ | ✅ |
| `libcap` | ✅ | ✅ |
| `lld_18` | ✅ | ✅ |
| `lld_19` | ✅ | ✅ |
| `lld_20` | ✅ | ✅ |
| `lld_21` | ✅ | ✅ |
| `lld_22` | ✅ | ✅ |
| `lsb-release` | ✅ | ✅ |
| `markdownlint-cli2` | 🩹 | — |
| `nettools` | ✅ | ✅ |
| `nodejs-slim24` | 🩹 | — |
| `nodejs-slim26` | 🩹 | — |
| `nsight-systems` | 🩹 | — |
| `numactl` | ✅ | ✅ |
| `opencommit` | 🩹 | — |
| `podman5` | 🩹 | — |
| `podman5-rootless` | 🩹 | — |
| `podman6` | 🩹 | — |
| `podman6-rootless` | 🩹 | — |
| `prettier` | 🩹 | — |
| `procps` | ✅ | ✅ |
| `protobuf_23` | ✅ 📌 | ✅ 📌 |
| `protobuf_24` | ✅ 📌 | ✅ 📌 |
| `protobuf_25` | ✅ | ✅ |
| `protobuf_26` | ✅ 📌 | ✅ 📌 |
| `protobuf_27` | ✅ | ✅ |
| `protobuf_28` | ✅ 📌 | ✅ 📌 |
| `protobuf_29` | ✅ | ✅ |
| `protobuf_3_8_0` | ✅ 📌 | ✅ 📌 |
| `protobuf_3_9_2` | 🩹 | — |
| `protobuf3_20` | ✅ 📌 | ✅ 📌 |
| `protobuf3_21` | ✅ 📌 | ✅ 📌 |
| `python311` | 🩹 | — |
| `python312` | 🩹 | — |
| `python313` | 🩹 | — |
| `python314` | 🩹 | — |
| `python315` | 🩹 | — |
| `qemu-user` | ✅ | ✅ |
| `s6` | 🩹 | — |
| `s6-dns` | ✅ | — |
| `s6-linux-init` | 🩹 | — |
| `s6-linux-utils` | ✅ | — |
| `s6-networking` | ✅ | — |
| `s6-portable-utils` | ✅ | — |
| `s6-rc` | 🩹 | — |
| `shadow` | 🩹 | — |
| `strace` | ✅ | ✅ |

## macOS only

| Package | macOS ARM64 |
| --- | :---: |
| `colima` | ✅ |
| `lima` | ✅ |

平台接线数据来源：[上游选择](../packages/upstream.nix)、[本地接线](../packages/default.nix)及
独立工具 workflow。修改包、平台接线或产品族平台边界时同步本表。
