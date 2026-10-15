# Package support

本表按当前包定义列出平台支持范围，不表示最新 CI 或远端发布状态。
macOS 仅支持 Apple Silicon；具体发布策略见[发布模型](release-model.md)。

- ✅：直接使用上游包；`binman`、`nixcache` 是本仓库独立构建的工具。
- 🩹：有包级本地定制，包括 patch、override、wrapper、资源打包或裁剪。
- 📌：选择非默认 nixpkgs channel。
- —：未接入该平台。

共用 build-tool 和 artifact 处理不逐包标记。同级 runtime 需要分别安装，见
[安装说明](../cmd/binman/USAGE.md)。`nsight-systems` 使用宿主 glibc；Darwin Rclone
有已知资源路径缺口，详见[产物边界](package-strategies/special-cases.md)。

## Cross-platform and macOS

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
| `colima` | — | — | ✅ |
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
| `gdu` | ✅ | ✅ | ✅ |
| `gettext` | ✅ | ✅ | ✅ |
| `gh` | ✅ | ✅ | ✅ |
| `ghostscript` | 🩹 | — | 🩹 |
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
| `go-task` | ✅ | ✅ | ✅ |
| `go-tools` | ✅ | ✅ | ✅ |
| `gofumpt` | ✅ | ✅ | ✅ |
| `golangci-lint` | ✅ | ✅ | ✅ |
| `gomodifytags` | ✅ | ✅ | ✅ |
| `gopls` | ✅ | ✅ | ✅ |
| `gost` | ✅ | ✅ | ✅ |
| `gotests` | ✅ | ✅ | ✅ |
| `gotools` | ✅ | ✅ | ✅ |
| `gzip` | ✅ | ✅ | ✅ |
| `imagemagick` | 🩹 | — | 🩹 |
| `impl` | ✅ | ✅ | ✅ |
| `inetutils` | ✅ | ✅ | ✅ |
| `jq` | ✅ | ✅ | ✅ |
| `krb5` | ✅ | ✅ | 🩹 |
| `lark-cli` | ✅ | ✅ | ✅ |
| `lefthook` | ✅ | ✅ | ✅ |
| `less` | ✅ | ✅ | ✅ |
| `libarchive` | ✅ | ✅ | ✅ |
| `libtool` | 🩹 | — | 🩹 |
| `lima` | — | — | ✅ |
| `lsof` | ✅ | ✅ | ✅ |
| `lxgw-wenkai` | ✅ | ✅ | ✅ |
| `m4` | ✅ | ✅ | ✅ |
| `makeself` | 🩹 | — | 🩹 |
| `mcfly` | ✅ | ✅ | ✅ |
| `miniserve` | ✅ | ✅ | ✅ |
| `ncdu_1` | ✅ | ✅ | ✅ |
| `nerd-fonts-fira-code` | ✅ | ✅ | ✅ |
| `nerd-fonts-ubuntu-mono` | ✅ | ✅ | ✅ |
| `netcat` | ✅ | ✅ | ✅ |
| `netron` | 🩹 | — | 🩹 |
| `ninja` | ✅ | ✅ | ✅ |
| `nixcache` | ✅ | ✅ | ✅ |
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
| `rclone` | ✅ | ✅ | ✅ |
| `revive` | ✅ | ✅ | ✅ |
| `rime-plugins` | 🩹 | — | 🩹 |
| `ripgrep` | ✅ | ✅ | ✅ |
| `rsync` | ✅ | ✅ | 🩹 |
| `ruff` | ✅ | ✅ | ✅ |
| `scc` | ✅ | ✅ | ✅ |
| `shellcheck` | ✅ | ✅ | ✅ 📌 |
| `shfmt` | ✅ | ✅ | ✅ |
| `smartmontools` | — | — | 🩹 |
| `sops` | ✅ | ✅ | ✅ |
| `sqlite` | ✅ | ✅ | ✅ |
| `starship` | ✅ | ✅ | ✅ |
| `supercronic` | ✅ | ✅ | ✅ |
| `tesseract` | 🩹 | — | 🩹 |
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
| `zip` | ✅ | ✅ | ✅ |
| `zsh` | 🩹 | — | 🩹 |
| `zsh-plugins` | 🩹 | — | 🩹 |
| `zstd` | ✅ | ✅ | ✅ |

## Linux only

以下包当前只接入 Linux。

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
| `cmake` | ✅ | ✅ |
| `cmake_3_27_9` | 🩹 | — |
| `cmake_4_1_2` | 🩹 | — |
| `codex` | 🩹 | — |
| `copyparty` | 🩹 | — |
| `cronie` | ✅ | ✅ |
| `dool` | 🩹 | — |
| `ethtool` | ✅ | ✅ |
| `execline` | 🩹 | — |
| `fuse` | 🩹 | — |
| `fuse3` | ✅ | ✅ |
| `gdb` | ✅ 📌 | ✅ 📌 |
| `git` | 🩹 | — |
| `glibcLocales` | ✅ | ✅ |
| `go` | 🩹 | — |
| `gocryptfs` | 🩹 | — |
| `graphviz` | 🩹 | — |
| `indent` | ✅ | ✅ |
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
| `lua5_5` | ✅ | ✅ |
| `man` | ✅ | ✅ |
| `markdownlint-cli2` | 🩹 | — |
| `mise` | 🩹 | — |
| `nettools` | ✅ | ✅ |
| `nil` | ✅ | ✅ |
| `nixfmt` | ✅ | ✅ |
| `nodejs-slim24` | 🩹 | — |
| `nodejs-slim26` | 🩹 | — |
| `nsight-systems` | 🩹 | — |
| `numactl` | ✅ | ✅ |
| `opencommit` | 🩹 | — |
| `openssh_gssapi` | 🩹 | — |
| `podman5` | 🩹 | — |
| `podman5-rootless` | 🩹 | — |
| `podman6` | 🩹 | — |
| `podman6-rootless` | 🩹 | — |
| `prettier` | 🩹 | — |
| `procps` | ✅ | ✅ |
| `protobuf3_20` | ✅ 📌 | ✅ 📌 |
| `protobuf3_21` | ✅ 📌 | ✅ 📌 |
| `protobuf_23` | ✅ 📌 | ✅ 📌 |
| `protobuf_24` | ✅ 📌 | ✅ 📌 |
| `protobuf_25` | ✅ | ✅ |
| `protobuf_26` | ✅ 📌 | ✅ 📌 |
| `protobuf_27` | ✅ | ✅ |
| `protobuf_28` | ✅ 📌 | ✅ 📌 |
| `protobuf_29` | ✅ | ✅ |
| `protobuf_3_8_0` | ✅ 📌 | ✅ 📌 |
| `protobuf_3_9_2` | 🩹 | — |
| `python311` | 🩹 | — |
| `python312` | 🩹 | — |
| `python313` | 🩹 | — |
| `python314` | 🩹 | — |
| `python315` | 🩹 | — |
| `qemu-user` | ✅ | ✅ |
| `radare2` | ✅ 📌 | — |
| `rizin` | 🩹 | — |
| `s6` | 🩹 | — |
| `s6-dns` | ✅ | — |
| `s6-linux-init` | 🩹 | — |
| `s6-linux-utils` | ✅ | — |
| `s6-networking` | ✅ | — |
| `s6-portable-utils` | ✅ | — |
| `s6-rc` | 🩹 | — |
| `shadow` | 🩹 | — |
| `strace` | ✅ | ✅ |
| `sudo` | 🩹 | — |
| `tmux` | ✅ | ✅ |
| `zellij` | ✅ | ✅ |

数据来源：[上游选择](../packages/upstream.nix)、[本地接线](../packages/default.nix)及
独立工具 workflow。修改包或平台接线时同步本表。
