# Linux 回归表（跨架构共享）

适用于 x86_64-linux 与 aarch64-linux，只列该平台有定制的包。仅 aarch64-linux 特有的差异见
[`linux-aarch64.md`](linux-aarch64.md)。表格约定、状态/定制图例与批量回归命令见
[`AGENTS.md`](AGENTS.md)。

`原因与保留边界`、`回归判据` 两列只给摘要，完整说明见「来源」列指向的 nix 文件注释；
Podman 的 systemd packaging 产品边界见 [`packages/podman/AGENTS.md`](../../packages/podman/AGENTS.md)。

| 包 | 定制 | 回归 | 原因与保留边界 | 回归判据 | commit | 来源 |
| --- | --- | --- | --- | --- | --- | --- |
| `autoconf` | 📦 本地 | ❌ | 相对路径 wrappers 定位配套脚本 | 上游入口无需 Nix store 路径时再评估 | — | `packages/autoconf/` |
| `aardvark-dns` | 🩹 本地 | ✅ | musl 无 `close_range` wrapper，patch 改用 raw syscall；详见 nix 注释 | 上游改用 musl-safe close_range 后删 patch | 56c02bc00adc | `packages/aardvark-dns/` |
| `atuin` | 📦 本地 | 🟡 | 预生成相对定位 init.zsh；详见 nix 注释 | 预生成 init 属产品行为保留 | dc5d91f84032 | `packages/atuin/` |
| `automake` | 📦 本地 | ❌ | 相对路径 wrappers 定位配套脚本 | 上游入口无需 Nix store 路径时再评估 | — | `packages/automake/` |
| `catatonit` | 🩹 本地 | ✅ | 清空 installCheckPhase（缺 readelf）；详见 nix 注释 | 上游修好 check 后恢复 | 624af665418d | `packages/catatonit/` |
| `clang-tools-18` | 📦 本地 | ❌ | 固定 LLVM 18，只提取瘦身 `clang-format` | 多版本单工具发布是产品决策 | — | `packages/clang-tools/` |
| `clang-tools-19` | 📦 本地 | ❌ | 固定 LLVM 19，只提取瘦身 `clang-format` | 多版本单工具发布是产品决策 | — | `packages/clang-tools/` |
| `clang-tools-20` | 📦 本地 | ❌ | 固定 LLVM 20，只提取瘦身 `clang-format` | 多版本单工具发布是产品决策 | — | `packages/clang-tools/` |
| `clang-tools-21` | 📦 本地 | ❌ | 固定 LLVM 21，只提取瘦身 `clang-format` | 多版本单工具发布是产品决策 | — | `packages/clang-tools/` |
| `clang-tools-22` | 📦 本地 | ❌ | 固定 LLVM 22，只提取瘦身 `clang-format` | 多版本单工具发布是产品决策 | — | `packages/clang-tools/` |
| `cloc` | 📦 本地 | 🟡 | `doInstallCheck=false`（沙箱无 sibling perl）+ Perl wrapper packaging；详见 nix 注释 | 只恢复可运行的 install check | 56c02bc00adc | `packages/cloc/` |
| `codex` | 🩹 本地 | 🟡 | 仅构建 `codex-cli`（丢弃 V8 backed code-mode-host）+ 去 wrapProgram store 路径 + 补 perl 建 vendored openssl；详见 nix 注释 | 上游 CLI 不再需要 code-mode-host 或 denoland 出 musl librusty_v8 后回 stock | dc5d91f84032 | `packages/codex/` |
| `cmake_3_27_9` | 📌 源码版本 + 🩹 | 🟡 | 保留 cstdint patch、`BUILD_TESTING=false`、openssl/curses 关闭；详见 nix 注释 | 上游修复后删剩余 workaround，保留版本化 output | 56c02bc00adc | `packages/cmake/3_27_9/` |
| `cmake_4_1_2` | 📌 源码版本 + 🩹 | 🟡 | 保留 `--no-system-libs`、openssl/curses 关闭、`BUILD_TESTING=false`；详见 nix 注释 | 上游支持静态 shared-module test 后删剩余 workaround | 56c02bc00adc | `packages/cmake/4_1_2/` |
| `conmon` | 🩹 本地 | ✅ | 清空 propagatedBuildInputs（systemd-minimal isStatic badPlatform）；详见 nix 注释 | stock unstable 无需清空即可 musl-static 构建 | 56c02bc00adc | `packages/conmon/` |
| `copyparty` | 📦 本地 | ❌ | 纯 Python + sibling runtime + 功能裁剪 | sibling runtime、依赖裁剪和功能边界属 packaging | — | `packages/copyparty/` |
| `crun` | 🩹 本地 | 🟡 | feature 禁用（elfutils badPlatform）+ `doCheck=false` + json-c 迁移；详见 nix 注释 | 逐项恢复 features/checks，保持 musl-static | dc5d91f84032 | `packages/crun/` |
| `curl` | 📦 本地 | ❌ | 内置 CA bundle 与相对路径 wrapper | 自包含证书定位是 packaging | — | `packages/curl/` |
| `diffutils` | 🩹 本地 | ✅ | 禁用 checks（9 个 gnulib 多线程/setlocale 测试 SIGABRT）；详见 nix 注释 | 上游全量 checks 与 musl-static 验证通过 | 56c02bc00adc | `packages/diffutils/` |
| `dive` | 📌 `25.11` | ✅ | 去 pin 失败（openldap 缺 Cyrus SASL）；详见 manifest 注释 | Linux 用 unstable 并满足 musl-static portability | 56c02bc00adc | `manifests/default.nix` |
| `dool` | 📦 本地 | ❌ | Python sibling runtime wrapper，默认追加 `--bytes` | runtime 与产品默认行为必须保留 | — | `packages/dool/` |
| `execline` | 📌 `s6-pin` + 🩹 本地 | 🟡 | s6 stack 统一 pin + 去 baked prefix patch；详见 nix 注释 | 上游修 s6 stack 后去 pin；输出无 store 路径 | 56c02bc00adc | `packages/execline/`, `flake.nix` |
| `exiftool` | 📦 本地 | 🟡 | `doInstallCheck=false` + sibling Perl/模块 bundling；详见 nix 注释 | 仅上游可运行 install check 时恢复 | 56c02bc00adc | `packages/exiftool/` |
| `eza-ls` | 📦 本地 | ❌ | 自定义 `ls` 兼容层与 bundled eza | 独立产品行为，不是上游 bug | — | `packages/eza-ls/` |
| `file` | 📦 本地 | ❌ | wrapper 相对定位 `magic.mgc` | 可搬运资源定位必须保留 | — | `packages/file/` |
| `fuse` | 🩹 本地 | 🟡 | 去 shadow/完整 util-linux 依赖（explicit_bzero SIGABRT）；详见 nix 注释 | 上游 libbsd 通过或 fuse2 不引 shadow 后删 override | 56c02bc00adc | `packages/fuse/` |
| `gdb` | 📌 `25.11` | ❌ | 历史 pin；unstable dejagnu→expect 链接失败（tclStubsPtr）；详见 manifest 注释 | 已确认必要，无可回归空间 | 624af665418d | `manifests/default.nix` |
| `git` | 🩹 本地 | 🟡 | test locale FAIL + 静态传递链接 + 相对资源 wrapper；详见 nix 注释 | 逐项删构建 workaround，保留 wrapper | 56c02bc00adc | `packages/git/` |
| `git-filter-repo` | 📦 本地 | ❌ | Python sibling runtime | runtime packaging 不会因上游构建修复消失 | — | `packages/git-filter-repo/` |
| `glibcLocales` | 📦 override | ❌ | 只发布裁剪后的 locale 数据 | 输出裁剪是产品决策 | — | `packages/local/linux/common.nix` |
| `gnupg` | 📦 override | ❌ | 明确启用 minimal 并关闭 GUI | feature selection 是产品决策 | — | `packages/local/common.nix` |
| `graphviz` | 🩹 + 📦 本地 | 🟡 | 关闭 LTDL/GIF/TIFF/WebP 等 + 相对字体入口；详见 nix 注释 | stock 直接 musl-static 后删编译 workaround；入口/字体/CLI packaging 保留 | 56c02bc00adc | `packages/graphviz/` |
| `gnutar` | 🩹 本地 | ✅ | `-Wl,--allow-multiple-definition`（xattrat 符号冲突）；详见 nix 注释 | stock 无 flag 也能静态链接并保留 ACL/xattr | 56c02bc00adc | `packages/gnutar/` |
| `gocryptfs` | 🩹 本地 | 🟡 | 清空 propagatedBuildInputs + 设 PKG_CONFIG_PATH；详见 nix 注释 | 上游 pcsclite doc 可构建、cross cgo 自动定位 openssl 后删 | 56c02bc00adc | `packages/gocryptfs/` |
| `gpgme` | 🩹 本地 | 🟡 | minimalGnuPG + `--disable-gpg-test` + `doCheck=false`；详见 nix 注释 | 逐项恢复依赖与 checks，保持 musl-static | 56c02bc00adc | `packages/gpgme/` |
| `libarchive` | 🩹 本地 | ✅ | 去 Nix store 路径、关 XAR/libxml2、保留 ZIP AES；详见 nix 注释 | stock 四 CLI 无 store 路径且 musl-static、smoke 通过 | 56c02bc00adc | `packages/libarchive/` |
| `libewf` | 🩹 本地 | ✅ | radare2/rizin 依赖；补 cross OpenSSL 探针 cache；详见 nix 注释 | 上游同 arch cross 不依赖运行探针后删 override | dc5d91f84032 | `packages/libewf/` |
| `libtool` | 📦 本地 | ❌ | 改写 `libtoolize` 的 baked data paths | 相对资源定位必须保留 | — | `packages/libtool/` |
| `lua5_5` | 🩹 本地 | ✅ | 恢复 `/usr/local` module paths，避免嵌 store 路径；详见 nix 注释 | stock 默认 module paths 无 store 路径 | 56c02bc00adc | `packages/lua/` |
| `makeself` | 📦 本地 | ❌ | wrapper 相对定位 header 资源 | 可搬运资源定位必须保留 | — | `packages/makeself/` |
| `markdownlint-cli2` | 📦 本地 | ❌ | JS 分发绑定 sibling Node runtime | sibling runtime packaging 必须保留 | — | `packages/markdownlint-cli2/` |
| `miniserve` | 📦 本地 | ❌ | wrapper 设置仓库要求的默认功能开关 | 产品行为必须保留 | — | `packages/miniserve/` |
| `music-decrypto` | ⚠️ glibc 动态 | 🟡 | Linux 仅长期审计 .NET AOT | Linux 出现 musl-static AOT | 56c02bc00adc | `packages/music-decrypto/` |
| `netron` | 📦 本地 | ❌ | wheel 重打包并绑定 sibling/宿主 Python | runtime packaging 必须保留 | — | `packages/netron/` |
| `nodejs-slim24` | 🩹 本地 | 🟡 | 保留 `ada`/`libuv` doCheck 与 node configureFlags；详见 nix 注释 | 逐 patch 验证删除，保留 Node 24 runtime | 56c02bc00adc | `packages/nodejs/24/` |
| `nodejs-slim26` | 🩹 本地 | 🟡 | 保留 `ada`/`libuv`/`lief`/`temporal_capi` 与 configureFlags；详见 nix 注释 | 逐 patch 删除，满足各平台动态依赖规则 | 56c02bc00adc | `packages/nodejs/26/` |
| `nsight-systems` | ⚠️ 预编译 glibc | ⏳ | NVIDIA 只提供 glibc 动态发行物 | 上游提供可用的 musl-static 发行物 | — | `packages/nsight-systems/` |
| `opencommit` | 📦 本地 | ❌ | JS 分发绑定 sibling Node runtime | sibling runtime packaging 必须保留 | — | `packages/opencommit/` |
| `openssh_gssapi` | 🩹 + 📦 本地 | ❌ | 相对定位 helpers + 关预认证 sandbox（QEMU 拒 seccomp）；详见 nix 注释 | 可搬运 helper 定位与跨架构 SSH 必须保留 | — | `packages/openssh_gssapi/` |
| `poppler` | 🩹 本地 | 🟡 | minimal+utils、关 openjpeg、补静态传递链接；详见 nix 注释 | unstable 直接 musl-static 或仅保留命名差异 | 56c02bc00adc | `packages/poppler/` |
| `pkgconf` | 🩹 本地 | ✅ | 改系统路径，避免二进制残留 store 路径；详见 nix 注释 | stock 二进制不再编译进 store 路径 | 56c02bc00adc | `packages/pkgconf/` |
| `parallel` | 📦 本地 | ❌ | 多入口 sibling Perl wrappers | runtime packaging 必须保留 | — | `packages/parallel/` |
| `patchelf` | 📌 `25.05` | ✅ | 历史 pin；unstable check `__TMC_END__` relocation 失败；详见 manifest 注释 | Linux 用 unstable 并满足 musl-static portability | 56c02bc00adc | `manifests/default.nix` |
| `perl` | 🩹 + 📦 本地 | 🟡 | 注入 Compress::Raw::Lzma + IO::Compress::Brotli 静态 XS + wrapper；详见 nix 注释 | 只删 stock 已覆盖的依赖/link patch | 56c02bc00adc | `packages/perl/` |
| `pnpm` | 📦 本地 | ❌ | JS 分发绑定 sibling Node runtime | sibling runtime packaging 必须保留 | — | `packages/pnpm/` |
| `podman5` | 🩹 + 📦 本地 | 🟡 | 跟随 5.x；packaging 与产品边界见 podman AGENTS.md | 分别回归编译修正；packaging 保留 | dc5d91f84032 | `packages/podman/AGENTS.md`、`packages/podman/podman5.nix` |
| `podman6` | 📌 + 🩹 + 📦 本地 | 🟡 | 固定 6.1.0；packaging 与产品边界见 podman AGENTS.md | 分别回归 pin/编译修正；packaging 保留 | dc5d91f84032 | `packages/podman/AGENTS.md`、`packages/podman/podman6.nix` |
| `postgresql` | 🩹 + 📦 本地 | 🟡 | `gccAsClang`、关 curl/gss、psql-only 边界；详见 nix 注释 | 逐项删 workaround，保留 psql-only 输出 | 56c02bc00adc | `packages/postgresql/` |
| `prettier` | 📦 本地 | ❌ | JS 分发绑定 sibling Node runtime | sibling runtime packaging 必须保留 | — | `packages/prettier/` |
| `protobuf3_20` | 📌 `24.05` | ❌ | unstable 已删除该版本，去 pin 静默产出空包；详见 manifest 注释 | 只能改指现存别名（改变版本语义），不属去 pin 回归 | 624af665418d | `manifests/default.nix` |
| `protobuf3_21` | 📌 `24.05` | ❌ | unstable 已改 throwing alias，去 pin eval 报错；详见 manifest 注释 | 只能改指现存别名（改变版本语义），不属去 pin 回归 | 624af665418d | `manifests/default.nix` |
| `protobuf_23` | 📌 `24.05` | ❌ | unstable 已删除该版本，去 pin 静默产出空包；详见 manifest 注释 | 只能改指现存别名（改变版本语义），不属去 pin 回归 | 624af665418d | `manifests/default.nix` |
| `protobuf_24` | 📌 `25.05` | ❌ | unstable 已 removed（throwing alias），去 pin eval 报错；详见 manifest 注释 | 只能改指现存别名（改变版本语义），不属去 pin 回归 | 624af665418d | `manifests/default.nix` |
| `protobuf_26` | 📌 `25.05` | ❌ | unstable 已 removed（throwing alias），去 pin eval 报错；详见 manifest 注释 | 只能改指现存别名（改变版本语义），不属去 pin 回归 | 624af665418d | `manifests/default.nix` |
| `protobuf_28` | 📌 `25.05` | ❌ | unstable 已 removed（throwing alias），去 pin eval 报错；详见 manifest 注释 | 只能改指现存别名（改变版本语义），不属去 pin 回归 | 624af665418d | `manifests/default.nix` |
| `protobuf_3_8_0` | 📌 源码版本 | ❌ | 明确发布 legacy protobuf 3.8.0 | 版本化产品，不回到最新 upstream | — | `packages/protobuf/3_8_0/` |
| `protobuf_3_9_2` | 📌 源码版本 | ❌ | 明确发布 legacy protobuf 3.9.2 | 版本化产品，不回到最新 upstream | — | `packages/protobuf/3_9_2/` |
| `python311` | 📦 本地 | ❌ | 静态 CPython 与内建扩展模块 | 多版本静态 runtime 是产品决策 | — | `packages/python/` |
| `python312` | 📦 本地 | ❌ | 静态 CPython 与内建扩展模块 | 多版本静态 runtime 是产品决策 | — | `packages/python/` |
| `python313` | 📦 本地 | ❌ | 静态 CPython 与内建扩展模块 | 多版本静态 runtime 是产品决策 | — | `packages/python/` |
| `python314` | 📦 本地 | ❌ | 静态 CPython 与内建扩展模块 | 多版本静态 runtime 是产品决策 | — | `packages/python/` |
| `python315` | 📦 本地 | ❌ | 静态 CPython 与内建扩展模块 | 多版本静态 runtime 是产品决策 | — | `packages/python/` |
| `radare2` | 🩹 本地 | ✅ | libewf override + sdb `both_libraries`→`library`；详见 nix 注释 | 上游 sdb 静态构建不产 `.so` 后删 override | dc5d91f84032 | `packages/radare2/` |
| `rime-plugins` | 📦 本地 | ❌ | 聚合多个 Rime 词库与转换结果 | 数据 bundle 是产品 | — | `packages/rime-plugins/` |
| `rizin` | 🩹 本地 | ✅ | libewf/tree-sitter override + 三处 cross-static 修复 + aarch64 关 pyyaml installCheck；详见 nix 注释 | 上游补齐 native cc/wrap/静态构建、pyyaml float repr 测试跨 arch 稳定后逐项删 | dc5d91f84032 | `packages/rizin/` |
| `runc` | 📦 native selection | ❌ | Linux 容器运行时，无 macOS 构建目标 | 无 macOS 端可回归空间（平台固有） | — | `manifests/default.nix` |
| `s6` | 📌 `s6-pin` + 🩹 本地 | 🟡 | s6 stack 统一 pin + 去 baked prefix patch；详见 nix 注释 | 上游修 s6 stack 后去 pin；输出无 store 路径 | 56c02bc00adc | `packages/s6/`, `flake.nix` |
| `s6-linux-init` | 📌 `s6-pin` + 🩹 本地 | 🟡 | s6 stack 统一 pin + 去 baked prefix patch + symlinkJoin；详见 nix 注释 | 上游修 s6 stack 后去 pin；产物与生成脚本无 store 路径 | 56c02bc00adc | `packages/s6-linux-init/`, `flake.nix` |
| `s6-rc` | 📌 `s6-pin` + 🩹 本地 | 🟡 | s6 stack 统一 pin + 去 baked prefix patch；详见 nix 注释 | 上游修 s6 stack 后去 pin；产物与生成服务无 store 路径 | 56c02bc00adc | `packages/s6-rc/`, `flake.nix` |
| `s6-dns` | 📌 `s6-pin` | 🟡 | s6 stack 统一 pin，无本地 patch；详见 flake.nix | 上游修 s6 stack 后去 `version` pin | 56c02bc00adc | `manifests/default.nix`, `flake.nix` |
| `s6-linux-utils` | 📌 `s6-pin` | 🟡 | s6 stack 统一 pin，无本地 patch；详见 flake.nix | 上游修 s6 stack 后去 `version` pin | 56c02bc00adc | `manifests/default.nix`, `flake.nix` |
| `s6-networking` | 📌 `s6-pin` | 🟡 | s6 stack 统一 pin，无本地 patch；详见 flake.nix | 上游修 s6 stack 后去 `version` pin | 56c02bc00adc | `manifests/default.nix`, `flake.nix` |
| `s6-portable-utils` | 📌 `s6-pin` | 🟡 | s6 stack 统一 pin，无本地 patch；详见 flake.nix | 上游修 s6 stack 后去 `version` pin | 56c02bc00adc | `manifests/default.nix`, `flake.nix` |
| `skalibs` | 📌 `s6-pin` | 🟡 | s6 stack 统一 pin，无本地 patch；详见 flake.nix | 上游修 s6 stack 后去 `version` pin | 56c02bc00adc | `manifests/default.nix`, `flake.nix` |
| `starship` | 📦 本地 | ❌ | 预生成相对定位 init.zsh；详见 nix 注释 | 预生成 init 与相对定位属产品行为，无回归空间 | — | `packages/starship/` |
| `sudo` | 🩹 本地 | 🟡 | 去 pam（`--disable-pam`）纯静态；setuid 外部设置；详见 nix 注释 | 上游 pam 可静态化后删 override；setuid 边界保留 | dc5d91f84032 | `packages/sudo/` |
| `tmux-plugins` | 📦 本地 | ❌ | 独立发布 `.tmux.conf` 数据 | 数据 bundle 是产品 | — | `packages/tmux-plugins/` |
| `tree-sitter` | 🩹 本地 | ✅ | rizin 依赖；精确删 `.so` 安装行（sed range 缺陷）；详见 nix 注释 | 上游修正 sed range 或静态不装 `.so` 后删 override | dc5d91f84032 | `packages/tree-sitter/` |
| `vim` | 📦 本地 | ❌ | wrapper 相对设置 `VIMRUNTIME` | 可搬运 runtime 定位必须保留 | — | `packages/vim/` |
| `vim-plugins` | 📦 本地 | ❌ | 聚合固定 Vim plugins | plugin bundle 是产品 | — | `packages/vim-plugins/` |
| `watchexec` | 🩹 本地 | ✅ | `--package=watchexec-cli` 排除 test crate；详见 nix 注释 | stock 输出不含 `test-socketfd` 且满足 portability | 56c02bc00adc | `packages/watchexec/` |
| `wget` | 🩹 + 📦 本地 | 🟡 | `doCheck=false`（fuzzer segfault）+ CA wrapper packaging；详见 nix 注释 | 恢复 checks/build tool 后保留 CA packaging | 56c02bc00adc | `packages/wget/` |
| `zellij` | 🩹 checks | 🟡 | 去 `26.05` pin 改 unstable，仍禁 checks（test 静态链符号未解析）；详见 nix 注释 | 上游 test 静态链接修复后恢复 checks | 56c02bc00adc | `packages/zellij/`, `packages/local/linux/common.nix` |
| `zsh` | 🩹 + 📦 本地 | 🟡 | 三个 `link=either` module + FPATH wrapper/zshenv packaging；详见 nix 注释 | 上游默认内建三 module 后删 patch，保留 packaging | 56c02bc00adc | `packages/zsh/` |
| `zsh-plugins` | 📦 本地 | ❌ | 聚合 oh-my-zsh 与 plugins | plugin bundle 是产品 | — | `packages/zsh-plugins/` |
