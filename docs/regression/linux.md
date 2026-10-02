# Linux 回归表（跨架构共享）

<!-- markdownlint-disable MD013 -->

适用于 x86_64-linux 与 aarch64-linux，只列该平台有定制的包。仅 aarch64-linux 特有的差异见
[`linux-aarch64.md`](linux-aarch64.md)。表格约定、状态/定制图例与批量回归命令见
[`AGENTS.md`](AGENTS.md)。

Podman 的 rootful systemd 与 rootless s6 packaging 产品边界分别见
[`packages/podman/DESIGN.md`](../../packages/podman/DESIGN.md) 和
[`packages/podman-rootless/DESIGN.md`](../../packages/podman-rootless/DESIGN.md)。

| 包 | 定制 | 回归 | 原因与保留边界 | 回归判据 | commit | 来源 |
| --- | --- | --- | --- | --- | --- | --- |
| `7zz` | 📌 `gcc15-pin` | ✅ | unstable 7zip 26.02 + GCC 16 链接 `7z.so` 时命中非 PIC 静态 libstdc++ 重定位错误 | 两个 Linux 架构用 unstable 构建并满足 musl-static portability | b4fd65b198c5 | `packages/upstream.nix`, `flake.nix` |
| `autoconf` | 📦 本地 | ❌ | 相对路径 wrappers 定位配套脚本 | 上游入口无需 Nix store 路径时再评估 | — | `packages/autoconf/` |
| `aardvark-dns` | 🩹 本地 | ✅ | musl 无 `close_range` wrapper，patch 改用 raw syscall | 上游改用 musl-safe close_range 后删 patch | b4fd65b198c5 | `packages/regression/aardvark-dns/` |
| `automake` | 📦 本地 | ❌ | 相对路径 wrappers 定位配套脚本 | 上游入口无需 Nix store 路径时再评估 | — | `packages/automake/` |
| `busybox` | 🩹 + 📦 本地 | 🟡 | udhcpc 与配套脚本改为 sibling 相对定位 | 上游支持可搬运资源定位后删 patch；保留脚本 packaging | b4fd65b198c5 | `packages/busybox/` |
| `catatonit` | 🩹 本地 | ✅ | 补 build-for-build binutils 让 installCheck 的 readelf 可用 | 上游把 binutils 加进 nativeBuildInputs 后恢复 | b4fd65b198c5 | `packages/regression/catatonit/` |
| `clang-tools-18` | 📦 本地 | ❌ | 固定 LLVM 18，只提取瘦身 `clang-format` | 多版本单工具发布是产品决策 | — | `packages/clang-tools/` |
| `clang-tools-19` | 📦 本地 | ❌ | 固定 LLVM 19，只提取瘦身 `clang-format` | 多版本单工具发布是产品决策 | — | `packages/clang-tools/` |
| `clang-tools-20` | 📦 本地 | ❌ | 固定 LLVM 20，只提取瘦身 `clang-format` | 多版本单工具发布是产品决策 | — | `packages/clang-tools/` |
| `clang-tools-21` | 📦 本地 | ❌ | 固定 LLVM 21，只提取瘦身 `clang-format` | 多版本单工具发布是产品决策 | — | `packages/clang-tools/` |
| `clang-tools-22` | 📦 本地 | ❌ | 固定 LLVM 22，只提取瘦身 `clang-format` | 多版本单工具发布是产品决策 | — | `packages/clang-tools/` |
| `cloc` | 📦 本地 | ❌ | sibling Perl wrapper 使 install check 在无 sibling runtime 的沙箱中不可运行 | runtime packaging 与对应的 check 边界必须保留 | — | `packages/perlPackages/cloc.nix` |
| `codex` | 🩹 本地 | 🟡 | CLI-only build、移除 store PATH wrapper、补 OpenSSL build tool | 上游 CLI 不再需要 code-mode-host 或 denoland 出 musl librusty_v8 后回 stock | b4fd65b198c5 | `packages/codex/` |
| `cmake_3_27_9` | 📌 源码版本 + 🩹 | 🟡 | 保留 cstdint patch、`BUILD_TESTING=false`、openssl/curses 关闭 | 上游修复后删剩余 workaround，保留版本化 output | b4fd65b198c5 | `packages/cmake/3_27_9/` |
| `cmake_4_1_2` | 📌 源码版本 + 🩹 | 🟡 | 保留 `--no-system-libs`、openssl/curses 关闭、`BUILD_TESTING=false` | 上游支持静态 shared-module test 后删剩余 workaround | b4fd65b198c5 | `packages/cmake/4_1_2/` |
| `conmon` | 🩹 本地 | ✅ | 清空 propagatedBuildInputs（systemd-minimal isStatic badPlatform） | stock unstable 无需清空即可 musl-static 构建 | b4fd65b198c5 | `packages/regression/conmon/` |
| `copyparty` | 📦 本地 | ❌ | 纯 Python + sibling runtime + 功能裁剪 | sibling runtime、依赖裁剪和功能边界属 packaging | — | `packages/pythonPackages/copyparty.nix` |
| `crun` | 🩹 本地 | 🟡 | feature 禁用（elfutils badPlatform）+ `doCheck=false` + json-c 迁移 | 逐项恢复 features/checks，保持 musl-static | b4fd65b198c5 | `packages/crun/` |
| `curl` | 📦 本地 | ❌ | 内置 CA bundle 与相对路径 wrapper | 自包含证书定位是 packaging | — | `packages/curl/` |
| `diffutils` | 🩹 本地 | ✅ | 禁用 checks（9 个 gnulib 多线程/setlocale 测试 SIGABRT） | 上游全量 checks 与 musl-static 验证通过 | b4fd65b198c5 | `packages/regression/diffutils/` |
| `dive` | 📌 `25.11` | ✅ | 去 pin 失败（openldap 缺 Cyrus SASL） | Linux 用 unstable 并满足 musl-static portability | b4fd65b198c5 | `packages/upstream.nix` |
| `dool` | 📦 本地 | ❌ | Python sibling runtime wrapper，默认追加 `--bytes` | runtime 与产品默认行为必须保留 | — | `packages/pythonPackages/dool.nix` |
| `execline` | 📌 `s6-pin` + 🩹 本地 | 🟡 | s6 stack 统一 pin + 去 baked prefix patch | 上游修 s6 stack 后去 pin；输出无 store 路径 | b4fd65b198c5 | `packages/s6Packages/execline.nix`, `flake.nix` |
| `exiftool` | 📦 本地 | ❌ | sibling Perl wrapper 与模块 bundling 使 install check 在构建沙箱中不可运行 | runtime packaging 与对应的 check 边界必须保留 | — | `packages/perlPackages/` |
| `eza-ls` | 📦 本地 | ❌ | 自定义 `ls` 兼容层与 bundled eza | 独立产品行为，不是上游 bug | — | `packages/eza-ls/` |
| `file` | 🩹 + 📦 本地 | 🟡 | version check 直指真实二进制；wrapper 相对定位 `magic.mgc` | 上游检查可兼容 wrapper 后删除检查修正；资源定位必须保留 | b4fd65b198c5 | `packages/file/` |
| `fuse` | 🩹 本地 | 🟡 | 去 shadow/完整 util-linux 依赖（explicit_bzero SIGABRT） | 上游 libbsd 通过或 fuse2 不引 shadow 后删 override | b4fd65b198c5 | `packages/fuse/` |
| `gdb` | 📌 `25.11` | ❌ | 历史 pin；unstable dejagnu→expect 链接失败（tclStubsPtr） | 已确认必要，无可回归空间 | 624af665418d | `packages/upstream.nix` |
| `git` | 🩹 本地 | 🟡 | test locale FAIL + 静态传递链接 + 相对资源 wrapper | 逐项删构建 workaround，保留 wrapper | b4fd65b198c5 | `packages/git/` |
| `git-filter-repo` | 📦 本地 | ❌ | Python sibling runtime | runtime packaging 不会因上游构建修复消失 | — | `packages/pythonPackages/git-filter-repo.nix` |
| `ghostscript` | 🩹 本地 | ✅ | 改用静态 `gs` target，跳过不存在的 `gsx` check | `pkgsStatic.ghostscript_headless` 直接生成可搬运静态 `gs` 后删除 override | b4fd65b198c5 | `packages/ghostscript/` |
| `glibcLocales` | 📦 override | ❌ | 只发布裁剪后的 locale 数据 | 输出裁剪是产品决策 | — | `packages/glibc-locales/` |
| `gnupg` | 📦 override | ❌ | 明确启用 minimal 并关闭 GUI | feature selection 是产品决策 | — | `packages/gnupg/` |
| `graphviz` | 🩹 + 📦 本地 | 🟡 | 关闭 LTDL/GIF/TIFF/WebP 等 + 相对字体入口 | stock 直接 musl-static 后删编译 workaround；入口/字体/CLI packaging 保留 | b4fd65b198c5 | `packages/graphviz/` |
| `gnutar` | 🩹 本地 | ✅ | `-Wl,--allow-multiple-definition`（xattrat 符号冲突） | stock 无 flag 也能静态链接并保留 ACL/xattr | b4fd65b198c5 | `packages/regression/gnutar/` |
| `go` | 🩹 + 📦 本地 | 🟡 | musl-static compiler；在 bootstrap 生成官方默认配置，对 race 强制外链，移除测试专用 dynamic ELF fixtures | 上游 static Go 默认值与 race link mode 对齐后删 patch；SDK packaging 与严格 ELF 门禁保留 | b4fd65b198c5 | `packages/go/` |
| `gocryptfs` | 🩹 本地 | 🟡 | 清空 propagatedBuildInputs + 设 PKG_CONFIG_PATH | 上游 pcsclite doc 可构建、cross cgo 自动定位 openssl 后删 | b4fd65b198c5 | `packages/gocryptfs/` |
| `gpgme` | 🩹 本地 | 🟡 | minimalGnuPG + `doCheck=false`；`--disable-gpg-test` 已删除 | 恢复完整 GnuPG 或 checks，保持 musl-static | b4fd65b198c5 | `packages/gpgme/` |
| `libewf` | 🩹 本地 | ✅ | radare2/rizin 依赖；补 cross OpenSSL 探针 cache | 上游同 arch cross 不依赖运行探针后删 override | b4fd65b198c5 | `packages/regression/libewf/` |
| `libtool` | 📦 本地 | ❌ | 改写 `libtoolize` 的 baked data paths | 相对资源定位必须保留 | — | `packages/libtool/` |
| `lua5_5` | 🩹 本地 | ✅ | 恢复 `/usr/local` module paths，避免嵌 store 路径 | stock 默认 module paths 无 store 路径 | b4fd65b198c5 | `packages/lua/` |
| `makeself` | 📦 本地 | ❌ | wrapper 相对定位 header 资源 | 可搬运资源定位必须保留 | — | `packages/makeself/` |
| `markdownlint-cli2` | 📦 本地 | ❌ | JS 分发绑定 sibling Node runtime | sibling runtime packaging 必须保留 | — | `packages/nodejsPackages/markdownlint-cli2.nix` |
| `mise` | 🩹 本地 | 🟡 | native Git 检查工具 + 跳过代理相关 DNS 测试 + PATH helper | static Git 与 DNS 测试修复后删 build workaround；保留 PATH portability patch | b4fd65b198c5 | `packages/mise/` |
| `netron` | 📦 本地 | ❌ | wheel 重打包并绑定 sibling/宿主 Python | runtime packaging 必须保留 | — | `packages/pythonPackages/netron.nix` |
| `nodejs-slim24` | 🩹 本地 | 🟡 | 保留 `ada` doCheck 与 node configureFlags | 逐 patch 验证删除，保留 Node 24 runtime | b4fd65b198c5 | `packages/nodejsPackages/nodejs/24.nix` |
| `nodejs-slim26` | 🩹 本地 | 🟡 | 保留 `ada`/`lief`/`temporal_capi` 与 configureFlags | 逐 patch 删除，满足各平台动态依赖规则 | b4fd65b198c5 | `packages/nodejsPackages/nodejs/26.nix` |
| `nsight-systems` | ⚠️ 预编译 glibc | ⏳ | NVIDIA 只提供 glibc 动态发行物 | 上游提供可用的 musl-static 发行物 | — | `packages/nsight-systems/` |
| `opencommit` | 📦 本地 | ❌ | JS 分发绑定 sibling Node runtime | sibling runtime packaging 必须保留 | — | `packages/nodejsPackages/opencommit.nix` |
| `openssh_gssapi` | 🩹 + 📦 本地 | ❌ | 相对定位 helpers + 关预认证 sandbox（QEMU 拒 seccomp） | 可搬运 helper 定位与跨架构 SSH 必须保留 | — | `packages/openssh_gssapi/` |
| `poppler` | 🩹 + 📦 本地 | 🟡 | 静态依赖裁剪与链接修正；相对字体/数据包装 | 静态构建 workaround 可回归后删除；可搬运资源打包保留 | b4fd65b198c5 | `packages/poppler/` |
| `pkgconf` | 🩹 本地 | ✅ | 改系统路径，避免二进制残留 store 路径 | stock 二进制不再编译进 store 路径 | b4fd65b198c5 | `packages/pkgconf/` |
| `parallel` | 📦 本地 | ❌ | 多入口 sibling Perl wrappers | runtime packaging 必须保留 | — | `packages/perlPackages/parallel.nix` |
| `patchelf` | 📌 `25.05` | ✅ | 历史 pin；unstable check `__TMC_END__` relocation 失败 | Linux 用 unstable 并满足 musl-static portability | b4fd65b198c5 | `packages/upstream.nix` |
| `perl` | 🩹 + 📦 本地 | 🟡 | 注入 Compress::Raw::Lzma + IO::Compress::Brotli 静态 XS + wrapper | 只删 stock 已覆盖的依赖/link patch | b4fd65b198c5 | `packages/perlPackages/` |
| `podman5` | 🩹 + 📦 本地 | 🟡 | 跟随 5.x；packaging 与产品边界见 podman DESIGN.md | 分别回归编译修正；packaging 保留 | b4fd65b198c5 | `packages/podman/DESIGN.md`、`packages/podman/podman5.nix` |
| `podman5-rootless` | 📦 本地 | ❌ | per-user wrapper、宿主 ID-map 接口、状态与 s6 packaging | 独立 rootless 产品边界必须保留 | — | `packages/podman-rootless/` |
| `podman6` | 📌 + 🩹 + 📦 本地 | 🟡 | 固定 6.1.0；packaging 与产品边界见 podman DESIGN.md | 分别回归 pin/编译修正；packaging 保留 | b4fd65b198c5 | `packages/podman/DESIGN.md`、`packages/podman/podman6.nix` |
| `podman6-rootless` | 📦 本地 | ❌ | per-user wrapper、宿主 ID-map 接口、状态与 s6 packaging | 独立 rootless 产品边界必须保留 | — | `packages/podman-rootless/` |
| `postgresql` | 🩹 + 📦 本地 | 🟡 | `gccAsClang`、关 curl/gss、psql-only 边界 | 逐项删 workaround，保留 psql-only 输出 | b4fd65b198c5 | `packages/postgresql/` |
| `prettier` | 📦 本地 | ❌ | JS 分发绑定 sibling Node runtime | sibling runtime packaging 必须保留 | — | `packages/nodejsPackages/prettier.nix` |
| `protobuf3_20` | 📌 `24.05` | ❌ | unstable 已删除该版本，去 pin 静默产出空包 | 只能改指现存别名（改变版本语义），不属去 pin 回归 | 624af665418d | `packages/upstream.nix` |
| `protobuf3_21` | 📌 `24.05` | ❌ | unstable 已改 throwing alias，去 pin eval 报错 | 只能改指现存别名（改变版本语义），不属去 pin 回归 | 624af665418d | `packages/upstream.nix` |
| `protobuf_23` | 📌 `24.05` | ❌ | unstable 已删除该版本，去 pin 静默产出空包 | 只能改指现存别名（改变版本语义），不属去 pin 回归 | 624af665418d | `packages/upstream.nix` |
| `protobuf_24` | 📌 `25.05` | ❌ | unstable 已 removed（throwing alias），去 pin eval 报错 | 只能改指现存别名（改变版本语义），不属去 pin 回归 | 624af665418d | `packages/upstream.nix` |
| `protobuf_26` | 📌 `25.05` | ❌ | unstable 已 removed（throwing alias），去 pin eval 报错 | 只能改指现存别名（改变版本语义），不属去 pin 回归 | 624af665418d | `packages/upstream.nix` |
| `protobuf_28` | 📌 `25.05` | ❌ | unstable 已 removed（throwing alias），去 pin eval 报错 | 只能改指现存别名（改变版本语义），不属去 pin 回归 | 624af665418d | `packages/upstream.nix` |
| `protobuf_3_8_0` | 📌 `22.11` | ❌ | 明确发布 legacy protobuf 3.8.0；使用仍提供该版本的最新 channel | 仅在更新 channel 仍提供 3.8.0 且构建 portable 时前移 | — | `packages/upstream.nix` |
| `protobuf_3_9_2` | 📌 源码版本 | ❌ | 明确发布 legacy protobuf 3.9.2；含该精确版本的 channel 均无法 musl-static 链接 | 新 channel 提供 3.9.2 且构建 portable 时切回 manifest | — | `packages/protobuf/3_9_2/` |
| `python311` | 📦 本地 | ❌ | 静态 CPython 与内建扩展模块 | 多版本静态 runtime 是产品决策 | — | `packages/pythonPackages/python/` |
| `python312` | 📦 本地 | ❌ | 静态 CPython 与内建扩展模块 | 多版本静态 runtime 是产品决策 | — | `packages/pythonPackages/python/` |
| `python313` | 📦 本地 | ❌ | 静态 CPython 与内建扩展模块 | 多版本静态 runtime 是产品决策 | — | `packages/pythonPackages/python/` |
| `python314` | 📦 本地 | ❌ | 静态 CPython 与内建扩展模块 | 多版本静态 runtime 是产品决策 | — | `packages/pythonPackages/python/` |
| `python315` | 📦 本地 | ❌ | 静态 CPython 与内建扩展模块 | 多版本静态 runtime 是产品决策 | — | `packages/pythonPackages/python/` |
| `radare2` | 🩹 本地 | ✅ | libewf override + sdb `both_libraries`→`library` | 上游 sdb 静态构建不产 `.so` 后删 override | b4fd65b198c5 | `packages/regression/radare2/` |
| `rime-plugins` | 📦 本地 | ❌ | 聚合多个 Rime 词库与转换结果 | 数据 bundle 是产品 | — | `packages/rime-plugins/` |
| `rizin` | 🩹 本地 | ✅ | libewf/tree-sitter 与 cross-static 构建修正 | 上游补齐 native cc/wrap/静态构建、pyyaml float repr 测试跨 arch 稳定后逐项删 | b4fd65b198c5 | `packages/rizin/` |
| `runc` | 📦 native selection | ❌ | Linux 容器运行时，无 macOS 构建目标 | 无 macOS 端可回归空间（平台固有） | — | `packages/upstream.nix` |
| `s6` | 📌 `s6-pin` + 🩹 本地 | 🟡 | s6 stack 统一 pin + 去 baked prefix patch | 上游修 s6 stack 后去 pin；输出无 store 路径 | b4fd65b198c5 | `packages/s6Packages/s6.nix`, `flake.nix` |
| `s6-linux-init` | 📌 `s6-pin` + 🩹 本地 | 🟡 | s6 stack 统一 pin + 去 baked prefix patch + symlinkJoin | 上游修 s6 stack 后去 pin；产物与生成脚本无 store 路径 | b4fd65b198c5 | `packages/s6Packages/s6-linux-init.nix`, `flake.nix` |
| `s6-rc` | 📌 `s6-pin` + 🩹 本地 | 🟡 | s6 stack 统一 pin + 去 baked prefix patch | 上游修 s6 stack 后去 pin；产物与生成服务无 store 路径 | b4fd65b198c5 | `packages/s6Packages/s6-rc.nix`, `flake.nix` |
| `s6-dns` | 📌 `s6-pin` | 🟡 | s6 stack 统一 pin，无本地 patch | 上游修 s6 stack 后去 `version` pin | b4fd65b198c5 | `packages/upstream.nix`, `flake.nix` |
| `s6-linux-utils` | 📌 `s6-pin` | 🟡 | s6 stack 统一 pin，无本地 patch | 上游修 s6 stack 后去 `version` pin | b4fd65b198c5 | `packages/upstream.nix`, `flake.nix` |
| `s6-networking` | 📌 `s6-pin` | 🟡 | s6 stack 统一 pin，无本地 patch | 上游修 s6 stack 后去 `version` pin | b4fd65b198c5 | `packages/upstream.nix`, `flake.nix` |
| `s6-portable-utils` | 📌 `s6-pin` | 🟡 | s6 stack 统一 pin，无本地 patch | 上游修 s6 stack 后去 `version` pin | b4fd65b198c5 | `packages/upstream.nix`, `flake.nix` |
| `shadow` | 🩹 + 📦 本地 | 🟡 | 关闭 libbsd 避免 musl `explicit_bzero` 测试 SIGABRT，并合并 `su` output | libbsd checks 修复后恢复 feature；保留完整命令集 packaging | b4fd65b198c5 | `packages/shadow/` |
| `skalibs` | 📌 `s6-pin` | 🟡 | s6 stack 统一 pin，无本地 patch | 上游修 s6 stack 后去 `version` pin | b4fd65b198c5 | `packages/upstream.nix`, `flake.nix` |
| `sudo` | 🩹 本地 | 🟡 | 去 pam（`--disable-pam`）纯静态；setuid 外部设置 | 上游 pam 可静态化后删 override；setuid 边界保留 | b4fd65b198c5 | `packages/sudo/` |
| `tmux-plugins` | 📦 本地 | ❌ | 独立发布 `.tmux.conf` 数据 | 数据 bundle 是产品 | — | `packages/tmux-plugins/` |
| `tree-sitter` | 🩹 本地 | ✅ | rizin 依赖；精确删 `.so` 安装行（sed range 缺陷） | 上游修正 sed range 或静态不装 `.so` 后删 override | b4fd65b198c5 | `packages/regression/tree-sitter/` |
| `vim` | 📦 本地 | ❌ | wrapper 相对设置 `VIMRUNTIME` | 可搬运 runtime 定位必须保留 | — | `packages/vim/` |
| `vim-plugins` | 📦 本地 | ❌ | 聚合固定 Vim plugins | plugin bundle 是产品 | — | `packages/vim-plugins/` |
| `wget` | 🩹 + 📦 本地 | 🟡 | `doCheck=false`（fuzzer segfault）+ CA wrapper packaging | 恢复 checks/build tool 后保留 CA packaging | b4fd65b198c5 | `packages/wget/` |
| `zsh` | 🩹 + 📦 本地 | 🟡 | 三个 `link=either` module + FPATH wrapper/zshenv packaging | 上游默认内建三 module 后删 patch，保留 packaging | b4fd65b198c5 | `packages/zsh/` |
| `zsh-plugins` | 📦 本地 | ❌ | 聚合 oh-my-zsh、plugins，并预生成 atuin/starship plugin | plugin bundle 与预生成 shell integration 是产品 | — | `packages/zsh-plugins/` |
