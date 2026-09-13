# macOS 回归表

适用于 aarch64-darwin，记录该平台的包级定制和公共 workaround。表格约定、状态/定制图例与批量回归命令见
[`AGENTS.md`](AGENTS.md)。

Go/CGO 的公共 resolver 路径修正由
[`artifact`](../../cmd/artifact/AGENTS.md#darwin-cgo-resolver) 维护严格门禁。
这属于集中维护 workaround，不代表 upstream 已修复；native selection 仍单独记录。

| 包 | 定制 | 回归 | 原因与保留边界 | 回归判据 | commit | 来源 |
| --- | --- | --- | --- | --- | --- | --- |
| `artifact-darwin-cgo-resolv` | 🩹 公共 artifact patch | ✅ | Darwin arm64 Go/CGO 的 Nix libresolv.9 dependency 由 artifact 严格门禁改指系统库；这是临时 portability workaround，不是永久 packaging。此前在 dc5d91f84032 的 stock gost 3.3.0 观察到原始 Nix dependency；尚未完成公共 patch 的独立移除回归。通用 Nix rpath 清理与必要重签不属于此候选 | 按下方 [Darwin CGO Resolver 回归](#darwin-cgo-resolver-回归) 绕过公共改写；所有当前受影响 source 的宿主 Mach-O 均无需该替换，最终 out/archive、签名、CGO DNS 与资源 smoke test 通过后删除 resolver 特例 | — | `cmd/artifact/binary.go`, `cmd/artifact/binary_test.go`, `lib/make-artifacts.nix` |
| `aria2` | 📌 `24.11` | ❌ | 已验证：unstable aria2 1.37.0 静态 darwin 构建链接 `libxml2.a` 时缺 `iconv`/`iconv_open`/`libiconv` 符号，链接失败 | 已确认必要，两平台都无可回归空间 | 624af665418d | `manifests/default.nix` |
| `atuin` | 📦 本地 | 🟡 | 跨平台本地包：随二进制预生成 `share/atuin/init.zsh` 并注入 prologue 用 `${(%):-%x}` 相对定位同包 `bin/atuin`；checkPhase 直接跑上游全量测试（未 skip）；darwin 未验证 | 预生成 init 保留 | — | `packages/atuin/` |
| `autoconf` | 📦 本地 | ❌ | 相对路径 wrappers 定位配套脚本 | 上游入口无需 Nix store 路径时再评估 | — | `packages/autoconf/` |
| `automake` | 📦 本地 | ❌ | 相对路径 wrappers 定位配套脚本 | 上游入口无需 Nix store 路径时再评估 | — | `packages/automake/` |
| `cloc` | 📦 本地 | 🟡 | sibling Perl wrapper 与模块 bundling 必须保留；install check 被禁用，darwin 未验证 | 只恢复可运行的 install check | — | `packages/cloc/` |
| `colima` | 📦 native selection | ✅ | darwin-only；manifest 保留 native，删除重复的 postInstall override；artifact 已负责还原 `.colima-wrapped` 和 resolver 修正。0.10.3 out/archive 构建、签名和禁读 `/nix` 的 version smoke 通过，最终目录与旧 override 一致；仍保留两者共有的 Go 资源 store 引用，详见下方记录 | 最终产物不再保留资源 store 引用；`pkgsStatic` 可构建且 portable 后恢复默认选择。公共 resolver 特例独立回归 | dc5d91f84032 | `manifests/default.nix`, `cmd/artifact/normalize.go`, `cmd/artifact/binary.go` |
| `curl` | 📦 本地 | ❌ | 内置 CA bundle 与相对路径 wrapper | 自包含证书定位是 packaging | — | `packages/curl/` |
| `docker-buildx` | 📦 native selection | ✅ | Darwin manifest 选择 native，绕过 static Go toolchain 缺 libresolv；包级 patch 已移除，resolver 路径由 artifact 严格门禁修正。0.35.0 最终 artifact 构建、依赖检查、签名和 version smoke test 通过 | `pkgsStatic` 可直接构建并满足 portability 后恢复默认选择 | dc5d91f84032 | `manifests/default.nix`, `cmd/artifact/binary.go` |
| `docker-compose` | 📦 native selection | ✅ | 仅 darwin 有定制（Linux 走零定制 manifest pkgsStatic 全静态）；darwin 上 stock `pkgsStatic` 构建 Go toolchain 时因缺静态 libresolv 失败，native stock binary 已只链接 macOS 系统 dylib，故 manifest 选择 `isStatic = false` | `pkgsStatic` 可直接构建并满足 macOS portability 后恢复默认选择 | 624af665418d | `manifests/default.nix` |
| `exiftool` | 📦 本地 | 🟡 | sibling Perl 与压缩模块 bundling 必须保留；install checks 被禁用，darwin 未验证 | install check 与 wrapper packaging 保留，仅在上游可运行 install check 时恢复 | — | `packages/exiftool/` |
| `eza-ls` | 📦 本地 | ❌ | 自定义 `ls` 兼容层与 bundled eza | 这是独立产品行为，不是上游 bug | — | `packages/eza-ls/` |
| `ffmpeg` | 🩹 本地 | 🟡 | 关闭无法静态化的 codec/network 链，修 x265 静态归档；native aarch64-darwin 会启用 FATE 测试，上游 flaky 用例 `fate-seek-hls`（断言精确 muxed 包大小，跨环境漂移如 3860 vs 3904）会中断构建，故 `doCheck = false` | 逐 feature 恢复，最终只依赖系统 dylib；上游修复 `fate-seek-hls` 稳定性后恢复检查 | — | `packages/ffmpeg/` |
| `file` | 📦 本地 | ❌ | wrapper 相对定位 `magic.mgc` | 可搬运资源定位必须保留 | — | `packages/file/` |
| `gdb` | 📌 `25.11` | ❌ | 已验证：unstable gdb 17.2 的 `dejagnu → expect` 静态 darwin 构建同样缺 `tclStubsPtr`/`tclIntStubsPtr`/`tclStubsPtr`（arm64 symbol not found），gdb 无法构建 | 已确认两平台都必要，无可回归空间 | 624af665418d | `manifests/default.nix` |
| `git-filter-repo` | 📦 本地 | ❌ | Python sibling runtime；macOS 暂用宿主 Python | runtime packaging 不会因上游构建修复消失 | — | `packages/git-filter-repo/` |
| `gnupg` | 📦 override | ❌ | 明确启用 minimal 并关闭 GUI | feature selection 是产品决策 | — | `packages/local/common.nix` |
| `golangci-lint` | 📦 native selection | ✅ | Darwin 保留 native selection，包级 resolver patch 已移至 artifact 严格门禁。2.13.2 最终 artifact 构建、依赖检查、签名和 version smoke test 通过 | `pkgsStatic` 可直接构建并满足 portability 后恢复默认选择 | dc5d91f84032 | `manifests/default.nix`, `cmd/artifact/binary.go` |
| `gost` | 📦 native selection | ✅ | Darwin 保留 native selection，包级 resolver patch 已移至 artifact 严格门禁；Linux 选择不变。3.3.0 最终 artifact 构建、依赖检查、签名和 version smoke test 通过 | `pkgsStatic` 可直接构建并满足 portability 后恢复默认选择 | dc5d91f84032 | `manifests/default.nix`, `cmd/artifact/binary.go` |
| `krb5` | 🩹 本地 | ❌ | 实测不可回归：去掉 override 后 stock unstable krb5 1.22.2 静态 darwin 构建时 `krb5kdc`/consumer 链接报 `_cc_initialize`（CCAPI 仅 `-framework Kerberos` 提供）与 `_krb5int_c_mit_des_zeroblock`（f_aead.o 未被静态 ld 拉入）两处 undefined symbol；禁用 CCAPI 与移动 DES const 的 patch 必须保留 | 上游修复 CCAPI 依赖与 DES const 静态可见性后删除 patch | 624af665418d | `packages/krb5/` |
| `lark-cli` | 📦 native selection | ❌ | manifest 在 macOS 选择 unstable native pkgs；关闭 CGO 反而产生 disallowed reference | 当前没有 pin 或 patch 可回归 | — | `manifests/default.nix` |
| `libarchive` | 🩹 本地 + ⏸️ 停用 darwin | 🟡 | 本地 override 在 macOS 上编译失败，暂时仅接入 Linux；Linux 仍需关闭 XAR/libxml2，并把静态 OpenSSL 的配置、engine 与 module 默认目录改为系统路径 | macOS 构建修复，且四个 CLI 均不内嵌 Nix store 路径、Mach-O 只依赖系统库并通过 TAR/ZIP/AES smoke test | — | `packages/local/linux/common.nix`, `packages/libarchive/` |
| `libtool` | 📦 本地 | ❌ | 改写 `libtoolize` 的 baked data paths | 相对资源定位必须保留 | — | `packages/libtool/` |
| `lima` | 📦 native selection | ✅ | darwin-only；manifest 保留 native，删除重复的 installPhase override；artifact 已负责去除 qemu PATH wrapper、resolver 修正和保留 entitlement 重签。2.2.0 out/archive 构建命令命中缓存，签名和基础 smoke 通过；仍有旧 override 同样存在的 Go 资源 store 引用，不能视为完整 portability 通过，详见下方记录 | 最终产物不再保留资源 store 引用；`pkgsStatic` 可构建且 portable 后恢复默认选择。公共 resolver 特例独立回归 | dc5d91f84032 | `manifests/default.nix`, `cmd/artifact/normalize.go`, `cmd/artifact/binary.go` |
| `makeself` | 📦 本地 | ❌ | wrapper 相对定位 header 资源 | 可搬运资源定位必须保留 | — | `packages/makeself/` |
| `markdownlint-cli2` | 📦 本地 | ❌ | JS 分发绑定 sibling Node runtime | sibling runtime packaging 必须保留 | — | `packages/markdownlint-cli2/` |
| `music-decrypto` | 🩹 ICU 路径 | 🟡 | macOS 可回归系统 ICU patch | macOS stock 仅用系统 dylib | — | `packages/music-decrypto/` |
| `netron` | 📦 本地 | ❌ | wheel 重打包并绑定 sibling/宿主 Python | runtime packaging 必须保留 | — | `packages/netron/` |
| `nixfmt` | ⏸️ 停用 darwin | 🟡 | stock `pkgsStatic` 构建在 macOS 上编译失败，暂时仅接入 Linux（两平台均走零定制 manifest pkgsStatic）| macOS 构建修复后恢复 `aarch64-darwin` | — | `manifests/default.nix` |
| `nodejs-slim26` | 🩹 本地 | 🟡 | 修 static deps、LIEF/Temporal、system libs 和 checks；macOS 注入 build tools，darwin 未验证 | 逐 patch 删除，最终满足各平台动态依赖规则 | — | `packages/nodejs/26/` |
| `opencommit` | 📦 本地 | ❌ | JS 分发绑定 sibling Node runtime | sibling runtime packaging 必须保留 | — | `packages/opencommit/` |
| `pkgconf` | 🩹 本地 | ✅ | stock `pkgconf-unwrapped` 把自身 Nix output 的 `.pc`、system lib/include 与 personality 路径编译进二进制；本地 override 改用标准 `/usr` 与 `/usr/local` 路径，避免 standalone 产物残留 `/nix/store` | stock 二进制不再编译进 Nix store 路径且只依赖系统 dylib | — | `packages/pkgconf/` |
| `parallel` | 📦 本地 | ❌ | 多入口 sibling Perl wrappers | runtime packaging 必须保留 | — | `packages/parallel/` |
| `perl` | 🩹 + 📦 本地 | 🟡 | macOS 静态替换与 install-name relocation；wrapper 必须保留，darwin 未验证 | 只删除 stock 已覆盖的依赖/link patch | — | `packages/perl/` |
| `pnpm` | 📦 本地 | ❌ | JS 分发绑定 sibling Node runtime | sibling runtime packaging 必须保留 | — | `packages/pnpm/` |
| `prettier` | 📦 本地 | ❌ | JS 分发绑定 sibling Node runtime | sibling runtime packaging 必须保留 | — | `packages/prettier/` |
| `protobuf_3_8_0` | 📌 源码版本 | ❌ | 明确发布 legacy protobuf 3.8.0 | 版本化产品，不回到最新 upstream | — | `packages/protobuf/3_8_0/` |
| `protobuf_3_9_2` | 📌 源码版本 | ❌ | 明确发布 legacy protobuf 3.9.2 | 版本化产品，不回到最新 upstream | — | `packages/protobuf/3_9_2/` |
| `rclone` | 📦 native selection | ✅ | 经用户确认，先删除资源 hash 清理 override，Darwin 改用 stock native 1.75.1 / Go 1.26.7；最终产物重新保留 tzdata/mailcap/iana-etc 引用，不是完整 portability 回归成功。resolver 仍由 artifact 修正；此前 `pkgsStatic` 在 Go bootstrap 缺 `-lresolv` 失败。out/archive、签名和禁读 `/nix` 的基础 smoke 通过，详见下方记录；Linux source derivation 未变 | 在工具链层恢复资源路径并验证无 store 依赖；`pkgsStatic` 可构建且 portable 后恢复默认选择。公共 resolver 特例独立回归 | dc5d91f84032 | `manifests/default.nix`, `cmd/artifact/binary.go`, `docs/package-strategies/go.md` |
| `rime-plugins` | 📦 本地 | ❌ | 聚合多个 Rime 词库与转换结果 | 数据 bundle 是产品 | — | `packages/rime-plugins/` |
| `rsync` | 🩹 本地 | ✅ | unstable rsync 3.5.0 在 `preBuild` 中插值 `python3` 以改写测试脚本；Darwin `pkgsStatic.python3` 被标记 broken，导致 package set 求值失败。启用 `strictDeps` 后测试 `partial-protected-regular-retry-policy` 又因裸 `cc -dynamiclib` 不在 PATH 而失败。静态 Darwin libiconv 还会把 Nix store 下的 i18n 数据目录编入 rsync。保留其余静态依赖，注入 native Python 和 check-only compiler，并把 native libiconv load command 改指系统 `/usr/lib/libiconv.2.dylib` | stock `pkgsStatic.rsync` 不再求值静态 Python、测试依赖完整，且不再内嵌 libiconv store 路径 | dc5d91f84032 | `packages/rsync/`, `packages/local/darwin.nix`, `manifests/default.nix` |
| `shellcheck` | 📌 `25.11` | ❌ | 已验证：unstable ShellCheck 0.11.0 静态 darwin 构建时 GHC 报 `External interpreter terminated (1)`，构建失败 | 已确认必要，无可回归空间 | 624af665418d | `manifests/default.nix` |
| `starship` | 📦 本地 | ❌ | 跨平台本地包：随二进制预生成 `share/starship/init.zsh`（native `starship init zsh`）并注入 prologue 用 `${(%):-%x}` 相对定位同包 `bin/starship`，把 baked 绝对二进制路径改写为该相对路径；darwin 未验证 | 预生成 init 与相对定位属产品行为，无上游回归空间 | — | `packages/starship/` |
| `supercronic` | 📦 native selection | ✅ | Darwin 保留 native selection，包级 resolver patch 已移至 artifact 严格门禁；Linux 选择不变。0.2.49 最终 artifact 构建、依赖检查、签名和 version smoke test 通过 | `pkgsStatic` 可直接构建并满足 portability 后恢复默认选择 | dc5d91f84032 | `manifests/default.nix`, `cmd/artifact/binary.go` |
| `tmux-plugins` | 📦 本地 | ❌ | 独立发布 `.tmux.conf` 数据 | 数据 bundle 是产品 | — | `packages/tmux-plugins/` |
| `uv` | 📌 `25.11` | ❌ | 已验证：unstable uv 0.11.32 静态 darwin 构建时 `aws-lc-sys` 的 `memcmp_invalid_stripped_check` 用 `--target arm64-apple-macosx` 触发 cc-wrapper 多 target 缺陷（`posix_spawn failed`），构建失败 | 已确认必要，无可回归空间 | 624af665418d | `manifests/default.nix` |
| `vim` | 📦 本地 | ❌ | wrapper 相对设置 `VIMRUNTIME` | 可搬运 runtime 定位必须保留 | — | `packages/vim/` |
| `vim-plugins` | 📦 本地 | ❌ | 聚合固定 Vim plugins | plugin bundle 是产品 | — | `packages/vim-plugins/` |
| `watchexec` | 🩹 本地 | ✅ | stock 在 workspace 根执行裸 `cargo build`，install hook 会把测试 crate `test-socketfd` 一并发布；本地 override 用 `--package=watchexec-cli` 只构建产品 CLI；darwin 仅完成 eval/dry-run | stock 输出不再包含 `test-socketfd`，且最终 Mach-O 只依赖系统库 | — | `packages/watchexec/` |
| `wget` | 🩹 + 📦 本地 | 🟡 | macOS 绕过 static Perl；CA wrapper 必须保留，darwin 未验证 | 恢复 checks/build tool 后保留 CA packaging | — | `packages/wget/` |
| `zsh` | 🩹 + 📦 本地 | 🟡 | 静态 module patches；FPATH wrapper 和 zshenv policy 必须保留 | 逐项删编译 patch，保留 relocation packaging | — | `packages/zsh/` |
| `zsh-plugins` | 📦 本地 | ❌ | 聚合 oh-my-zsh 与 plugins | plugin bundle 是产品 | — | `packages/zsh-plugins/` |

## Colima Override 回归

在 `dc5d91f84032` 的 Colima 0.10.3 中，本地 postInstall 仅省略上游 PATH wrapper，
completion 逻辑不变；artifact 已将 `.colima-wrapped` 还原为真实入口。同一 artifact
工具处理有、无 override 的 source 后，目录和 tar.gz 均逐字节相同，因此改用 manifest
的 Darwin native 包。上游 source closure 会带上 `lima-full/qemu/docker/krunkit`，
增加 source 缓存体积，但这些工具不进入最终 tarball，运行时仍需单独安装并通过 PATH 解析。

切换后 `nix build .#colima .#tarballs.aarch64-darwin.colima` 使用缓存上游 source，
实际构建了 standalone out/archive；最终目录和未压缩 TAR 内容与此前旧 override 的
验证产物一致，archive 解包与 out 一致。Mach-O 只链接系统库且严格签名验证通过，
解包后禁止读取 `/nix` 的 `colima version` 通过；未重新编译上游或启动 VM。

最终 out 仍引用 `tzdata-2026c`、`mailcap-2.1.54`、`iana-etc-20251215`，
旧 override 同样存在；本次未改变资源查找行为，不能视为完整 portability 通过。
资源行为与 native selection 后续单独验证，公共 resolver 特例继续按独立候选回归。

## Lima Override 回归

在 `dc5d91f84032` 的 Lima 2.2.0 中，本地 installPhase 仅省略上游 qemu PATH wrapper；
artifact 的 `prepareFile` 已将 `.limactl-wrapped` 还原为真实入口。旧 override 的
`limactl` 与 stock native 的 `.limactl-wrapped` 逐字节相同，因此删除包级重复逻辑，
在 manifest 保留 Darwin native selection，不改变 Linux 包集合。

`nix build .#lima .#tarballs.aarch64-darwin.lima` 成功命中缓存；archive 解包与 out
内容一致。三个宿主 Mach-O 只链接系统库且严格签名验证通过，limactl 保留 virtualization
与 network entitlements。解包后禁止读取 `/nix`，`limactl --version`、`lima --version`
和 `template copy template:default` 均通过。没有重新编译上游、启动 VM 或验证完整资源行为。

额外检查发现最终 out 的 Nix references 仍包含 `tzdata-2026c`、`mailcap-2.1.54`、
`iana-etc-20251215`，三个宿主 Mach-O 均内嵌资源 store 路径；旧 override 的 source
同样保留这三项。此次只删除重复 override，不新增资源清理或放宽校验；这是既有未解决的
portability 问题，不能将系统动态库检查和基础 smoke 成功表述为完全无 store 依赖。
后续资源处理须验证实际资源查找行为，不能仅替换 hash；公共 resolver 仍按独立候选回归。

## Rclone 资源路径

经用户确认，先删除 Darwin 的 `remove-references-to` override 及其三项
`disallowedReferences`，由 manifest 选择 stock native。旧处理只是把资源 hash
改成不可解析占位值，不是系统路径重定位；此次取消是策略调整，不是上游已修复。
不扩大到其他包，也不修改 Go 工具链或公共 artifact 校验。

在 `dc5d91f84032` 的 stock native 1.75.1 / Go 1.26.7 中，source 引用
`libresolv-96`、`tzdata-2026c`、`mailcap-2.1.54`、`iana-etc-20251215`。
最终 artifact 只修正 resolver，Nix references 重新包含后三项；有对应 Nix 数据的
机器可能重新使用它们。时区和 MIME 仍有系统查找，IANA 的 Go 文件查询没有原
`/etc/services`、`/etc/protocols` 路径回退，不能假定所有资源行为都不受环境影响。
来源与后续方向见 [Go 资源路径](../package-strategies/go.md#go-资源路径)。

`nix build .#rclone .#tarballs.aarch64-darwin.rclone` 使用缓存上游 source，
实际构建了最终 out/archive；三个入口只链接系统库，严格签名验证通过，
archive 解包与 out 内容一致。解包后禁止读取 `/nix`，version、本地 copy/check 和
`.abw` MIME 查询通过。两个 Linux source drvPath 与切换前相同，未重建 Linux。
本次未重新编译上游、运行全仓测试、挂载 macFUSE、访问真实云端后端，也未重跑
完整时区、DNS、服务名和协议名测试；此前清理版本的验证不当作新产物的验证。

后续需在工具链层恢复标准资源路径并验证 consumer，再关闭这一缺口；不能将基础 smoke
或系统动态库检查通过表述为完全无 store 依赖。公共 resolver 修正仍独立回归。

## Darwin CGO Resolver 回归

`artifact-darwin-cgo-resolv` 是公共组件候选 ID，不是可构建的 package attr。
每次 nixpkgs bump 后，按该行的 commit 和通用队列规则重新评估；不能因包级 patch 已删除
或 consumer 的 packaging 行标为结构性保留而跳过它；已切到 manifest 的 `colima` 和
`lima` 仍须覆盖。

1. 从当前 flake 的 `sources.aarch64-darwin` 核对实际使用的 source 和 Go toolchain，
   检查未经过 artifact 的宿主 Mach-O，包括 `bin`、`libexec` 和其他随包 helper。
   初始验证集至少包含 `gost`、`supercronic`、`golangci-lint`、`docker-buildx`、
   `colima`、`lima`、`rclone`；同时纳入当前 source 中新发现的 Go/CGO resolver consumer。
   仍在发布的旧 channel/toolchain 也要覆盖，不能仅凭某一个 Go 版本修复就删除全局规则。
2. 在一次性工作副本中，仅移除 `normalizeMachO` 调用
   `darwinCGOResolvDependencies` 并生成 resolver `-change` 参数的部分。保留原有
   rpath 清理、签名和 portability validation，不添加永久 bypass flag，也不降低门禁。
   普通 `probe` 虽绕过包级 patch，仍会经过公共 artifact 改写，不能作为无此 patch 的证据。
3. 使用相同 lock 和 package selection 构建该副本的受影响 `out` 与 `archive`。
   对每个宿主 Mach-O 检查原始及最终 load commands；匹配函数返回空不代表上游修好，
   build info 缺失或路径格式变化也会不匹配。若任一原始 consumer 仍含 Nix resolver
   dependency，即有保留依据；记录包、Go 版本、实际路径和失败日志，保留候选并更新 commit。
   若只验证了部分成功样本，不得记录为本 revision 的完整回归通过。
4. 全部目标无需替换后，验证签名、版本命令和代表性行为；CGO DNS smoke test 应确认实际
   走 CGO resolver（例如 `GODEBUG=netdns=cgo+1`），并验证 Lima entitlement、
   wrapper 与模板读取。构建/运行成本无法覆盖时明确记录未验证项，不删除公共 patch。
5. 验证通过后删除 resolver 专用 matcher、helper、调用和对应测试，保留通用 rpath 清理、
   必要重签及其测试。同步组件文档、Nix/workflow 注释和包行中的 resolver 描述，再删除此候选。
   native selection 与 Go 资源路径缺口独立验证，不因公共 resolver patch 删除而自动解决。
