# Linux 回归表

<!-- markdownlint-disable MD013 -->

记录 x86_64-linux 的本地定制，以及两个 Linux 平台共用的 upstream manifest 选择。
`aarch64-linux` 不消费表中来源位于 `packages/` 的本地 derivation 或
`packages/static-build-tools.nix` overlay；该平台只在
[`linux-aarch64.md`](linux-aarch64.md) 记录 upstream-only 边界与 manifest 差异。表格约定、
状态/定制图例与批量回归命令见 [`AGENTS.md`](AGENTS.md)。

Podman 的 rootful systemd 与 rootless s6 packaging 产品边界分别见
[`packages/podman/DESIGN.md`](../../packages/podman/DESIGN.md) 和
[`packages/podman-rootless/DESIGN.md`](../../packages/podman-rootless/DESIGN.md)。

| 包 | 定制 | 回归 | 原因与保留边界 | 回归判据 | 已测 unstable | 来源 |
| --- | --- | --- | --- | --- | --- | --- |
| `7zz` | 📌 `gcc15-pin` | ✅ | unstable 7zip 26.04 + GCC 16 链接 `7z.so` 时命中非 PIC 静态 libstdc++ 重定位错误 | 两个 Linux 架构用 unstable 构建并满足 musl-static portability | f4a03c008967 | `packages/upstream.nix`, `flake.nix` |
| `autoconf` | 📦 本地 | ❌ | 相对路径 wrappers 定位配套脚本 | 上游入口无需 Nix store 路径时再评估 | — | `packages/autoconf/` |
| `atuin` | 🩹 本地 | ✅ | SQLx proc macro 的 host pkg-config 误用 musl SQLite/OpenSSL；显式提供原生库与 pkg-config，保留 target 静态依赖 | stock 正确区分 host/target 库且全部 checks、搬迁后的 history 操作通过后删除 | f4a03c008967 | `packages/regression/atuin/` |
| `aardvark-dns` | 🩹 Podman 内部依赖 | ✅ | musl 无 `close_range` wrapper，patch 改用 raw syscall | 上游改用 musl-safe close_range 后删 patch | f4a03c008967 | `packages/regression/aardvark-dns/` |
| `aws-lc-build-go` | 🩹 公共 producer override | ✅ | symbol generator 继承 cross Go 默认值找不到 target CC；用 native Go 并对纯 Go 工具设置 `CGO_ENABLED=0`，保留 SSL checks | stock producer 的 symbol generator 与 SSL test runner 使用正确的 build-platform Go/CC 后删除 | f4a03c008967 | `packages/regression/aws-lc/`, `packages/static-build-tools.nix` |
| `automake` | 📦 本地 | ❌ | 相对路径 wrappers 定位配套脚本 | 上游入口无需 Nix store 路径时再评估 | — | `packages/automake/` |
| `buildah` | 🩹 本地 | ✅ | 纯 Go OpenPGP 避开完整 GnuPG→OpenLDAP 的 musl-static Cyrus SASL 失败 | stock `buildah-unwrapped` 使用静态兼容的签名 backend 通过完整 artifact 流程 | f4a03c008967 | `packages/regression/buildah/` |
| `build-tool-splicing` | 🩹 公共 package-set patch | ✅ | Graphite2/Node/Rizin 的 build-only Python 和 Rizin 的 build-only Perl 使用 native package set；门禁错误平台的 native inputs | 各 upstream producer 正确选择 native build tool 后逐项删除 override；门禁保留 | — | `packages/static-build-tools.nix`, `lib/validate-native-build-inputs.nix` |
| `go-build-tool` | 🩹 公共 package-set patch | ✅ | 默认及版本化 `buildGoModule` 的 native Go 移除三个资源路径 patch；未移除时 Age 最终二进制仍嵌入失效的 tzdata/IANA store 路径 | stock native Go 不再向 consumer 嵌入 store 资源路径 | f4a03c008967 | `packages/static-build-tools.nix` |
| `busybox` | 🩹 + 📦 本地 | 🟡 | udhcpc 与配套脚本改为 sibling 相对定位 | 上游支持可搬运资源定位后删 patch；保留脚本 packaging | b4fd65b198c5 | `packages/busybox/` |
| `clang-tools-18` | 📦 本地 | ❌ | 固定 LLVM 18，只提取瘦身 `clang-format` | 多版本单工具发布是产品决策 | — | `packages/clang-tools/` |
| `clang-tools-19` | 📦 本地 | ❌ | 固定 LLVM 19，只提取瘦身 `clang-format` | 多版本单工具发布是产品决策 | — | `packages/clang-tools/` |
| `clang-tools-20` | 📦 本地 | ❌ | 固定 LLVM 20，只提取瘦身 `clang-format` | 多版本单工具发布是产品决策 | — | `packages/clang-tools/` |
| `clang-tools-21` | 📦 本地 | ❌ | 固定 LLVM 21，只提取瘦身 `clang-format` | 多版本单工具发布是产品决策 | — | `packages/clang-tools/` |
| `clang-tools-22` | 📦 本地 | ❌ | 固定 LLVM 22，只提取瘦身 `clang-format` | 多版本单工具发布是产品决策 | — | `packages/clang-tools/` |
| `clang-tools-23` | 📦 本地 | ❌ | 固定 LLVM 23，只提取瘦身 `clang-format` | 多版本单工具发布是产品决策 | — | `packages/clang-tools/` |
| `cloc` | 📦 本地 | ❌ | sibling Perl wrapper 使 install check 在无 sibling runtime 的沙箱中不可运行 | runtime packaging 与对应的 check 边界必须保留 | — | `packages/perlPackages/cloc.nix` |
| `codex` | 🩹 本地 | 🟡 | CLI-only build，移除 daemon store-layout patch 与 postInstall；补原生 Perl/Clang 和系统 Oniguruma、Rust Jemalloc、AWS-LC | 上游 musl CLI 可独立构建且 helper/metadata 不依赖 store 后逐项移除；保留 PATH helper 行为 | b4fd65b198c5 | `packages/codex/` |
| `cmake_3_27_9` | 📌 源码版本 + 🩹 | 🟡 | 保留 cstdint patch、`BUILD_TESTING=false`、openssl/curses 关闭 | 上游修复后删剩余 workaround，保留版本化 output | b4fd65b198c5 | `packages/cmake/3_27_9/` |
| `cmake_4_1_2` | 📌 源码版本 + 🩹 | 🟡 | 保留 `--no-system-libs`、openssl/curses 关闭、`BUILD_TESTING=false` | 上游支持静态 shared-module test 后删剩余 workaround | b4fd65b198c5 | `packages/cmake/4_1_2/` |
| `copyparty` | 📦 本地 | ❌ | 纯 Python + sibling runtime + 功能裁剪 | sibling runtime、依赖裁剪和功能边界属 packaging | — | `packages/pythonPackages/copyparty.nix` |
| `crun` | 🩹 Podman 内部依赖 | 🟡 | feature 禁用（elfutils badPlatform）+ `doCheck=false` + json-c 迁移 | 逐项恢复 features/checks，保持 musl-static | f4a03c008967 | `packages/regression/crun/` |
| `curl` | 📦 本地 | ❌ | 内置 CA bundle 与相对路径 wrapper | 自包含证书定位是 packaging | — | `packages/curl/` |
| `dool` | 📦 本地 | ❌ | Python sibling runtime wrapper，默认追加 `--bytes` | runtime 与产品默认行为必须保留 | — | `packages/pythonPackages/dool.nix` |
| `execline` | 🩹 本地 | 🟡 | 去 baked prefix patch | 输出无 store 路径 | b4fd65b198c5 | `packages/s6Packages/execline.nix` |
| `exiftool` | 📦 本地 | ❌ | sibling Perl wrapper 与模块 bundling 使 install check 在构建沙箱中不可运行 | runtime packaging 与对应的 check 边界必须保留 | — | `packages/perlPackages/` |
| `eza-ls` | 📦 本地 | ❌ | `ls` 命令行为与内置 eza | 独立产品行为，不是上游 bug | — | `packages/eza-ls/` |
| `file` | 🩹 + 📦 本地 | 🟡 | version check 直指真实二进制；wrapper 相对定位 `magic.mgc` | 上游检查可兼容 wrapper 后删除检查修正；资源定位必须保留 | f4a03c008967 | `packages/file/` |
| `ffmpeg` | 🩹 本地 | 🟡 | 裁剪 static-unsupported 依赖链、libbluray、LAME decoder、x265 multibit；修正 SoXR/libssh/SVT-AV1/x265 静态产物；增大 musl 线程栈以容纳 MPEG-TS PAT parser | 逐 feature 恢复并去掉依赖 override；上游不再在线程栈放置超大 `struct Program` 后删除 stack-size；保持 musl-static、无 store 引用 | — | `packages/ffmpeg/linux.nix` |
| `gdb` | 📌 `25.11` | ✅ | unstable 的 Expect 错选 target Tcl，正式 native-input 门禁失败，raw probe 仍链接失败于 `tclStubsPtr` | unstable 的 dejagnu/expect 可构建并通过最终 artifact 验证后删除 pin | f4a03c008967 | `packages/upstream.nix` |
| `gh` | 🩹 本地 | ✅ | token refresh 测试加载 America/New_York；仅在 checks 提供 tzdata 和 ZONEINFO，避免依赖 compiler 内置 store 数据路径 | stock 显式提供测试时区数据且全部 checks/artifact 通过后删除 | f4a03c008967 | `packages/regression/gh/` |
| `git` | 🩹 本地 | 🟡 | musl install checks 失败 + 静态传递链接 + 相对资源 wrapper | 逐项删构建 workaround，保留 wrapper | f4a03c008967 | `packages/git/` |
| `git-filter-repo` | 📦 本地 | ❌ | Python sibling runtime | runtime packaging 不会因上游构建修复消失 | — | `packages/pythonPackages/git-filter-repo.nix` |
| `ghostscript` | 🩹 本地 | ✅ | 改用静态 `gs` target，跳过不存在的 `gsx` check | `pkgsStatic.ghostscript_headless` 直接生成可搬运静态 `gs` 后删除 override | f4a03c008967 | `packages/regression/ghostscript/` |
| `graphviz` | 🩹 + 📦 本地 | 🟡 | 关闭 LTDL/GIF/TIFF/WebP 等 + 相对字体入口 | stock 直接 musl-static 后删编译 workaround；入口/字体/CLI packaging 保留 | b4fd65b198c5 | `packages/graphviz/` |
| `gnutar` | 🩹 本地 | ✅ | `-Wl,--allow-multiple-definition`（xattrat 符号冲突） | stock 无 flag 也能静态链接并保留 ACL/xattr | f4a03c008967 | `packages/regression/gnutar/` |
| `go` | 🩹 + 📦 本地 | 🟡 | musl-static compiler；在 bootstrap 生成官方默认配置，对 race 强制外链，移除测试专用 dynamic ELF fixtures | 上游 static Go 默认值与 race link mode 对齐后删 patch；SDK packaging 与严格 ELF 门禁保留 | b4fd65b198c5 | `packages/go/` |
| `gocryptfs` | 🩹 本地 | 🟡 | 清空 propagatedBuildInputs + 设 PKG_CONFIG_PATH | 上游 pcsclite doc 可构建、cross cgo 自动定位 openssl 后删 | f4a03c008967 | `packages/regression/gocryptfs/` |
| `gpgme` | 🩹 Podman 内部依赖 | 🟡 | `gnupgMinimal` + `doCheck=false` | 恢复完整 GnuPG 或 checks，保持 musl-static | f4a03c008967 | `packages/regression/gpgme/` |
| `imagemagick` | 🩹 + 📦 本地 | 🟡 | 修正 Potrace cross getopt 误判，关闭静态构建失败的四项 delegate，并嵌入 zero-configuration 资源 | 逐项恢复 stock 依赖；保留可搬运配置，ImageMagick 完整 artifact 通过 | f4a03c008967 | `packages/regression/imagemagick/linux.nix` |
| `libtool` | 📦 本地 | ❌ | 改写 `libtoolize` 的 baked data paths | 相对资源定位必须保留 | — | `packages/libtool/` |
| `makeself` | 📦 本地 | ❌ | wrapper 相对定位 header 资源 | 可搬运资源定位必须保留 | — | `packages/makeself/` |
| `markdownlint-cli2` | 📦 本地 | ❌ | JS 分发绑定 sibling Node runtime | sibling runtime packaging 必须保留 | — | `packages/nodejsPackages/markdownlint-cli2.nix` |
| `mise` | 🩹 本地 | 🟡 | 修复 static-musl nextest list fixture 竞争与 target-dependent rustup 测试、为 FHS 测试注入 native tools + PATH helper | upstream tests 兼容 static-musl target、list guard 改用可靠 phase signal 且不再硬编码 FHS 路径后逐项删 test workaround；保留 PATH portability patch | 7fd4004d0511 | `packages/mise/` |
| `netron` | 📦 本地 | ❌ | wheel 重打包并绑定 sibling/宿主 Python | runtime packaging 必须保留 | — | `packages/pythonPackages/netron.nix` |
| `nodejs-slim24` | 🩹 本地 | 🟡 | 保留 `ada` doCheck 与 node configureFlags | 逐 patch 验证删除，保留 Node 24 runtime | b4fd65b198c5 | `packages/nodejsPackages/nodejs/24.nix` |
| `nodejs-slim26` | 🩹 本地 | 🟡 | 保留 `ada`/`lief`/`temporal_capi` 与 configureFlags | 逐 patch 删除，满足各平台动态依赖规则 | b4fd65b198c5 | `packages/nodejsPackages/nodejs/26.nix` |
| `nsight-systems` | ⚠️ 预编译 glibc | ⏳ | NVIDIA 只提供 glibc 动态发行物 | 上游提供可用的 musl-static 发行物 | — | `packages/nsight-systems/` |
| `opencommit` | 📦 本地 | ❌ | JS 分发绑定 sibling Node runtime | sibling runtime packaging 必须保留 | — | `packages/nodejsPackages/opencommit.nix` |
| `openssh_gssapi` | 🩹 + 📦 本地 | ❌ | 相对定位 helpers + 关预认证 sandbox（QEMU 拒 seccomp） | 可搬运 helper 定位与跨架构 SSH 必须保留 | — | `packages/openssh_gssapi/` |
| `poppler` | 🩹 + 📦 本地 | 🟡 | 静态依赖裁剪与链接修正；相对字体/数据包装 | 静态构建 workaround 可回归后删除；可搬运资源打包保留 | b4fd65b198c5 | `packages/poppler/` |
| `parallel` | 📦 本地 | ❌ | 多入口 sibling Perl wrappers | runtime packaging 必须保留 | — | `packages/perlPackages/parallel.nix` |
| `patchelf` | 📌 `25.05` | ✅ | unstable check `__TMC_END__` relocation 失败 | Linux 用 unstable 并满足 musl-static portability | f4a03c008967 | `packages/upstream.nix` |
| `perl` | 🩹 + 📦 本地 | 🟡 | 注入 Compress::Raw::Lzma + IO::Compress::Brotli 静态 XS + wrapper | 只删 stock 已覆盖的依赖/link patch | b4fd65b198c5 | `packages/perlPackages/` |
| `pnpm` | 🩹 本地 | ✅ | Rust 依赖的 host C helper 错误继承全局 `-static`，仅对该 helper 禁用此 flag | stock `pkgsStatic.pnpm` 的完整 artifact 流程通过 | f4a03c008967 | `packages/regression/pnpm/linux.nix` |
| `podman5` | 📌 源码版本 + 🩹 + 📦 本地 | 🟡 | 固定最新 5.x 维护版 5.8.9；去 systemd outputs、恢复静态 runc；packaging 见 Podman DESIGN.md | 分别回归编译修正；5.x 版本边界与 packaging 保留 | 7fd4004d0511 | `packages/podman/DESIGN.md`、`packages/podman/podman5.nix` |
| `podman5-rootless` | 📦 本地 | ❌ | per-user wrapper、宿主 ID-map 接口、状态与 s6 packaging | 独立 rootless 产品边界必须保留 | — | `packages/podman-rootless/` |
| `podman6` | 📌 + 🩹 + 📦 本地 | 🟡 | 固定 6.1.0、去 systemd outputs、恢复静态 runc；packaging 与产品边界见 podman DESIGN.md | 分别回归编译修正；6.1.0 版本与 packaging 保留 | 7fd4004d0511 | `packages/podman/DESIGN.md`、`packages/podman/podman6.nix` |
| `podman6-rootless` | 📦 本地 | ❌ | per-user wrapper、宿主 ID-map 接口、状态与 s6 packaging | 独立 rootless 产品边界必须保留 | — | `packages/podman-rootless/` |
| `postgresql` | 🩹 + 📦 本地 | 🟡 | `gccAsClang`、关 curl/gss、psql-only 边界 | 逐项删 workaround，保留 psql-only 输出 | f4a03c008967 | `packages/postgresql/` |
| `prettier` | 📦 本地 | ❌ | JS 分发绑定 sibling Node runtime | sibling runtime packaging 必须保留 | — | `packages/nodejsPackages/prettier.nix` |
| `protobuf3_20` | 📌 `24.05` | ❌ | unstable 已删除该版本，去 pin 静默产出空包 | 只能改指现存别名（改变版本语义），不属去 pin 回归 | 624af665418d | `packages/upstream.nix` |
| `protobuf3_21` | 📌 `24.05` | ❌ | unstable 已改 throwing alias，去 pin eval 报错 | 只能改指现存别名（改变版本语义），不属去 pin 回归 | 624af665418d | `packages/upstream.nix` |
| `protobuf_23` | 📌 `24.05` | ❌ | unstable 已删除该版本，去 pin 静默产出空包 | 只能改指现存别名（改变版本语义），不属去 pin 回归 | 624af665418d | `packages/upstream.nix` |
| `protobuf_24` | 📌 `25.05` | ❌ | unstable 已 removed（throwing alias），去 pin eval 报错 | 只能改指现存别名（改变版本语义），不属去 pin 回归 | 624af665418d | `packages/upstream.nix` |
| `protobuf_26` | 📌 `25.05` | ❌ | unstable 已 removed（throwing alias），去 pin eval 报错 | 只能改指现存别名（改变版本语义），不属去 pin 回归 | 624af665418d | `packages/upstream.nix` |
| `protobuf_28` | 📌 `25.05` | ❌ | unstable 已 removed（throwing alias），去 pin eval 报错 | 只能改指现存别名（改变版本语义），不属去 pin 回归 | 624af665418d | `packages/upstream.nix` |
| `protobuf_3_8_0` | 📌 `22.11` | ❌ | 发布 protobuf 3.8.0；使用仍提供该版本的最新 channel | 仅在更新 channel 仍提供 3.8.0 且构建 portable 时前移 | — | `packages/upstream.nix` |
| `protobuf_3_9_2` | 📌 源码版本 | ❌ | 发布 protobuf 3.9.2；含该精确版本的 channel 均无法 musl-static 链接 | 新 channel 提供 3.9.2 且构建 portable 时切回 manifest | — | `packages/protobuf/3_9_2/` |
| `python311` | 📦 本地 | ❌ | 静态 CPython 与内建扩展模块 | 多版本静态 runtime 是产品决策 | — | `packages/pythonPackages/python/` |
| `python312` | 📦 本地 | ❌ | 静态 CPython 与内建扩展模块 | 多版本静态 runtime 是产品决策 | — | `packages/pythonPackages/python/` |
| `python313` | 📦 本地 | ❌ | 静态 CPython 与内建扩展模块 | 多版本静态 runtime 是产品决策 | — | `packages/pythonPackages/python/` |
| `python314` | 📦 本地 | ❌ | 静态 CPython 与内建扩展模块 | 多版本静态 runtime 是产品决策 | — | `packages/pythonPackages/python/` |
| `python315` | 📦 本地 | ❌ | 静态 CPython 与内建扩展模块 | 多版本静态 runtime 是产品决策 | — | `packages/pythonPackages/python/` |
| `radare2` | 📦 本地 | ❌ | stock 编译通过，但 baked prefix 使搬迁后类型库缺失；相对 wrapper 设置原生 `R2_PREFIX` | 上游按 executable 相对定位 SDB 数据后再评估包装 | — | `packages/radare2/` |
| `rime-plugins` | 📦 本地 | ❌ | 聚合多个 Rime 词库与转换结果 | 数据 bundle 是产品 | — | `packages/rime-plugins/` |
| `rizin` | 🩹 本地 | ✅ | native cc/wrap 与 libdemangle 静态构建修正 | 上游逐项补齐后删除对应 override | f4a03c008967 | `packages/regression/rizin/` |
| `ripgrep` | 🩹 本地 | ✅ | Cargo hook 禁止隐式 vendored Jemalloc，但 stock 15.2.0 缺少 `rust-jemalloc-sys`，命中不存在的 `JEMALLOC_OVERRIDE` sentinel | stock 声明系统 Rust Jemalloc 并通过完整 checks、静态 artifact 与 PCRE2 smoke 后删除 | f4a03c008967 | `packages/regression/ripgrep/` |
| `s6` | 🩹 本地 | 🟡 | 去 baked prefix patch | 输出无 store 路径 | b4fd65b198c5 | `packages/s6Packages/s6.nix` |
| `s6-linux-init` | 🩹 + 📦 本地 | 🟡 | 去 baked prefix patch + symlinkJoin | 产物与生成脚本无 store 路径 | b4fd65b198c5 | `packages/s6Packages/s6-linux-init.nix` |
| `s6-rc` | 🩹 本地 | 🟡 | 去 baked prefix patch | 产物与生成服务无 store 路径 | b4fd65b198c5 | `packages/s6Packages/s6-rc.nix` |
| `shadow` | 🩹 + 📦 本地 | 🟡 | 关闭 libbsd 避免 musl `explicit_bzero` 测试 SIGABRT，并合并 `su` output | libbsd checks 修复后恢复 feature；保留完整命令集 packaging | f4a03c008967 | `packages/shadow/` |
| `skaware-build-pkg-config` | 🩹 公共 | 🟡 | cross-static scope 注入 build-platform pkg-config | 上游 scope 正确 splice pkg-config 后删除公共 override | f4a03c008967 | `packages/static-build-tools.nix` |
| `sudo` | 🩹 本地 | 🟡 | 去 pam（`--disable-pam`）纯静态；setuid 外部设置 | 上游 pam 可静态化后删 override；setuid 边界保留 | b4fd65b198c5 | `packages/sudo/` |
| `tesseract` | 📦 本地 | ❌ | 真实二进制与 `tessdata_best` 的 `eng`/`chi_sim`/`chi_tra`/`osd` 使用相对路径 wrapper 共同打包，其他模型由外部 `TESSDATA_PREFIX` 提供 | 可搬运 tessdata 定位和中英文最高精度默认数据必须保留 | e12c65a91594 | `packages/tesseract/` |
| `tmux-plugins` | 📦 本地 | ❌ | 独立发布 `.tmux.conf` 数据 | 数据 bundle 是产品 | — | `packages/tmux-plugins/` |
| `vim` | 📦 本地 | ❌ | wrapper 相对设置 `VIMRUNTIME` | 可搬运 runtime 定位必须保留 | — | `packages/vim/` |
| `vim-plugins` | 📦 本地 | ❌ | 聚合固定 Vim plugins | plugin bundle 是产品 | — | `packages/vim-plugins/` |
| `wget` | 🩹 + 📦 本地 | 🟡 | `doCheck=false`（fuzzer segfault）+ CA wrapper packaging | 恢复 checks/build tool 后保留 CA packaging | f4a03c008967 | `packages/wget/` |
| `zsh` | 🩹 + 📦 本地 | 🟡 | 三个 `link=either` module + FPATH wrapper/zshenv packaging | 上游默认内建三 module 后删 patch，保留 packaging | f4a03c008967 | `packages/zsh/` |
| `zsh-plugins` | 📦 本地 | ❌ | 聚合 oh-my-zsh、plugins，并预生成 atuin/starship plugin | plugin bundle 与预生成 shell integration 是产品 | — | `packages/zsh-plugins/` |
