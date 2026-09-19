# macOS 回归表

适用于 aarch64-darwin，记录该平台的包级定制和公共 workaround。表格约定、状态/定制图例与批量回归命令见
[`AGENTS.md`](AGENTS.md)。

`原因与保留边界`、`回归判据` 两列只给摘要，完整说明见「来源」列指向的 nix 文件（或公共实现）注释。
Go/CGO 公共 resolver 路径修正由 [`artifact`](../../cmd/artifact/AGENTS.md#darwin-cgo-resolver)
维护严格门禁，移除步骤见下方 [Darwin CGO Resolver 回归](#darwin-cgo-resolver-回归)。

| 包 | 定制 | 回归 | 原因与保留边界 | 回归判据 | commit | 来源 |
| --- | --- | --- | --- | --- | --- | --- |
| `artifact-darwin-cgo-resolv` | 🩹 公共 artifact patch | ✅ | libresolv.9 dependency 由 artifact 改指系统库；临时 portability workaround；详见 cmd/artifact/AGENTS.md | 按下方 [Darwin CGO Resolver 回归](#darwin-cgo-resolver-回归) 绕过后全部宿主 Mach-O 无需替换、smoke 通过再删 | — | `cmd/artifact/binary.go`, `cmd/artifact/binary_test.go`, `lib/make-artifacts.nix` |
| `aria2` | 📌 `24.11` | ❌ | unstable 静态 darwin 缺 iconv 符号链接失败；详见 manifest 注释 | 已确认必要，两平台都无可回归空间 | 624af665418d | `manifests/default.nix` |
| `atuin` | 📦 本地 | 🟡 | 预生成相对定位 init.zsh；darwin 未验证；详见 nix 注释 | 预生成 init 保留 | — | `packages/atuin/` |
| `autoconf` | 📦 本地 | ❌ | 相对路径 wrappers 定位配套脚本 | 上游入口无需 Nix store 路径时再评估 | — | `packages/autoconf/` |
| `automake` | 📦 本地 | ❌ | 相对路径 wrappers 定位配套脚本 | 上游入口无需 Nix store 路径时再评估 | — | `packages/automake/` |
| `cloc` | 📦 本地 | 🟡 | sibling Perl wrapper/模块 bundling；install check 禁用；darwin 未验证 | 只恢复可运行的 install check | — | `packages/cloc/` |
| `colima` | 📦 native selection | ✅ | darwin-only native；artifact 还原 wrapper/resolver；仍有 Go 资源 store 引用（见下方记录） | 产物不再保留资源 store 引用后恢复默认；resolver 特例独立回归 | dc5d91f84032 | `manifests/default.nix`, `cmd/artifact/normalize.go`, `cmd/artifact/binary.go` |
| `curl` | 📦 本地 | ❌ | 内置 CA bundle 与相对路径 wrapper | 自包含证书定位是 packaging | — | `packages/curl/` |
| `docker-buildx` | 📦 native selection | ✅ | native 绕过 static Go 缺 libresolv；resolver 由 artifact 修正；详见 manifest 注释 | `pkgsStatic` 可构建并 portable 后恢复默认 | dc5d91f84032 | `manifests/default.nix`, `cmd/artifact/binary.go` |
| `docker-compose` | 📦 native selection | ✅ | darwin native（pkgsStatic Go 缺 libresolv）；详见 manifest 注释 | `pkgsStatic` 可构建并满足 portability 后恢复默认 | 624af665418d | `manifests/default.nix` |
| `exiftool` | 📦 本地 | 🟡 | sibling Perl/压缩模块 bundling；install checks 禁用；darwin 未验证 | 仅上游可运行 install check 时恢复 | — | `packages/exiftool/` |
| `eza-ls` | 📦 本地 | ❌ | 自定义 `ls` 兼容层与 bundled eza | 独立产品行为，不是上游 bug | — | `packages/eza-ls/` |
| `ffmpeg` | 🩹 本地 | 🟡 | 关无法静态化的 codec/network + 修 x265；`doCheck=false`（FATE flaky）；详见 nix 注释 | 逐 feature 恢复只依赖系统 dylib；上游修 flaky 后恢复检查 | — | `packages/ffmpeg/` |
| `file` | 📦 本地 | ❌ | wrapper 相对定位 `magic.mgc` | 可搬运资源定位必须保留 | — | `packages/file/` |
| `gdb` | 📌 `25.11` | ❌ | unstable dejagnu→expect 静态 darwin 缺 tclStubsPtr；详见 manifest 注释 | 已确认两平台都必要，无可回归空间 | 624af665418d | `manifests/default.nix` |
| `git-filter-repo` | 📦 本地 | ❌ | Python sibling runtime；macOS 暂用宿主 Python | runtime packaging 不会因上游构建修复消失 | — | `packages/git-filter-repo/` |
| `gnupg` | 📦 override | ❌ | 明确启用 minimal 并关闭 GUI | feature selection 是产品决策 | — | `packages/local/common.nix` |
| `golangci-lint` | 📦 native selection | ✅ | native；resolver 由 artifact 修正；详见 manifest 注释 | `pkgsStatic` 可构建并 portable 后恢复默认 | dc5d91f84032 | `manifests/default.nix`, `cmd/artifact/binary.go` |
| `gost` | 📦 native selection | ✅ | native；resolver 由 artifact 修正；详见 manifest 注释 | `pkgsStatic` 可构建并 portable 后恢复默认 | dc5d91f84032 | `manifests/default.nix`, `cmd/artifact/binary.go` |
| `krb5` | 🩹 本地 | ❌ | 禁 CCAPI + 移 DES const（静态 darwin 两处 undefined symbol）；详见 nix 注释 | 上游修复 CCAPI/DES 静态可见性后删 patch | 624af665418d | `packages/krb5/` |
| `lark-cli` | 📦 native selection | ❌ | macOS 选 unstable native（关 CGO 反而 disallowed reference）；详见 manifest 注释 | 当前没有 pin 或 patch 可回归 | — | `manifests/default.nix` |
| `libarchive` | 🩹 本地 + ⏸️ 停用 darwin | 🟡 | macOS 编译失败暂仅接入 Linux；Linux 去 store 路径、关 XAR/libxml2；详见 nix 注释 | macOS 构建修复且四 CLI 无 store 路径、只依赖系统库、smoke 通过 | — | `packages/local/linux/common.nix`, `packages/libarchive/` |
| `libtool` | 📦 本地 | ❌ | 改写 `libtoolize` 的 baked data paths | 相对资源定位必须保留 | — | `packages/libtool/` |
| `lima` | 📦 native selection | ✅ | darwin-only native；artifact 去 qemu wrapper/resolver、保留 entitlement；仍有 Go 资源 store 引用（见下方记录） | 产物不再保留资源 store 引用后恢复默认；resolver 特例独立回归 | dc5d91f84032 | `manifests/default.nix`, `cmd/artifact/normalize.go`, `cmd/artifact/binary.go` |
| `makeself` | 📦 本地 | ❌ | wrapper 相对定位 header 资源 | 可搬运资源定位必须保留 | — | `packages/makeself/` |
| `markdownlint-cli2` | 📦 本地 | ❌ | JS 分发绑定 sibling Node runtime | sibling runtime packaging 必须保留 | — | `packages/markdownlint-cli2/` |
| `music-decrypto` | 🩹 ICU 路径 | 🟡 | macOS 可回归系统 ICU patch | macOS stock 仅用系统 dylib | — | `packages/music-decrypto/` |
| `netron` | 📦 本地 | ❌ | wheel 重打包并绑定 sibling/宿主 Python | runtime packaging 必须保留 | — | `packages/netron/` |
| `nixfmt` | ⏸️ 停用 darwin | 🟡 | stock pkgsStatic macOS 编译失败，暂仅接入 Linux；详见 manifest 注释 | macOS 构建修复后恢复 `aarch64-darwin` | — | `manifests/default.nix` |
| `nodejs-slim26` | 🩹 本地 | 🟡 | 修 static deps/LIEF/Temporal/system libs/checks；darwin 未验证；详见 nix 注释 | 逐 patch 删除，满足各平台动态依赖规则 | — | `packages/nodejs/26/` |
| `opencommit` | 📦 本地 | ❌ | JS 分发绑定 sibling Node runtime | sibling runtime packaging 必须保留 | — | `packages/opencommit/` |
| `pkgconf` | 🩹 本地 | ✅ | 改系统路径，避免二进制残留 store 路径；详见 nix 注释 | stock 二进制不再嵌 store 路径且只依赖系统 dylib | — | `packages/pkgconf/` |
| `parallel` | 📦 本地 | ❌ | 多入口 sibling Perl wrappers | runtime packaging 必须保留 | — | `packages/parallel/` |
| `perl` | 🩹 + 📦 本地 | 🟡 | macOS 静态替换 + install-name relocation + wrapper；darwin 未验证；详见 nix 注释 | 只删除 stock 已覆盖的依赖/link patch | — | `packages/perl/` |
| `pnpm` | 📦 本地 | ❌ | JS 分发绑定 sibling Node runtime | sibling runtime packaging 必须保留 | — | `packages/pnpm/` |
| `postgresql` | 🩹 + 📦 本地 | 🟡 | 基于 `pkgsStatic.libpq` 追加 psql，改系统 OpenSSL 目录；详见 nix 注释 | `pkgsStatic.libpq` 上游提供 psql 且不嵌依赖路径 | dc5d91f84032 | `packages/postgresql/` |
| `prettier` | 📦 本地 | ❌ | JS 分发绑定 sibling Node runtime | sibling runtime packaging 必须保留 | — | `packages/prettier/` |
| `protobuf_3_8_0` | 📌 源码版本 | ❌ | 明确发布 legacy protobuf 3.8.0 | 版本化产品，不回到最新 upstream | — | `packages/protobuf/3_8_0/` |
| `protobuf_3_9_2` | 📌 源码版本 | ❌ | 明确发布 legacy protobuf 3.9.2 | 版本化产品，不回到最新 upstream | — | `packages/protobuf/3_9_2/` |
| `radare2` | ⏸️ 停用 darwin | ❌ | 产品不要求 macOS 支持；仅在 Linux 包集合接入 | 产品边界，不作为上游回归目标 | — | `packages/local/linux/common.nix` |
| `rclone` | 📦 native selection | ✅ | 用户确认改 native，删资源 hash 清理；仍保留 tzdata/mailcap/iana-etc 引用（见下方记录） | 工具链层恢复资源路径且无 store 依赖后关闭；resolver 特例独立回归 | dc5d91f84032 | `manifests/default.nix`, `cmd/artifact/binary.go`, `docs/package-strategies/go.md` |
| `rime-plugins` | 📦 本地 | ❌ | 聚合多个 Rime 词库与转换结果 | 数据 bundle 是产品 | — | `packages/rime-plugins/` |
| `rizin` | ⏸️ 停用 darwin | ❌ | 产品不要求 macOS 支持；仅在 Linux 包集合接入 | 产品边界，不作为上游回归目标 | — | `packages/local/linux/common.nix` |
| `rsync` | 🩹 本地 | ✅ | 注入 native Python/check compiler + libiconv 指系统库；详见 nix 注释 | stock 不再求值静态 Python、测试完整、不嵌 libiconv store 路径 | dc5d91f84032 | `packages/rsync/`, `packages/local/darwin.nix`, `manifests/default.nix` |
| `shellcheck` | 📌 `25.11` | ❌ | unstable 静态 darwin GHC External interpreter terminated；详见 manifest 注释 | 已确认必要，无可回归空间 | 624af665418d | `manifests/default.nix` |
| `smartmontools` | 🩹 本地 | 🟡 | 关外部 drive DB + native autoreconfHook/hostname（避 static Perl）；详见 nix 注释 | static Perl 修复后删 build-tool override；CLI 配置保留 | dc5d91f84032 | `packages/smartmontools/darwin.nix`, `packages/local/darwin.nix` |
| `starship` | 📦 本地 | ❌ | 预生成相对定位 init.zsh；darwin 未验证；详见 nix 注释 | 预生成 init 与相对定位属产品行为，无回归空间 | — | `packages/starship/` |
| `supercronic` | 📦 native selection | ✅ | native；resolver 由 artifact 修正；详见 manifest 注释 | `pkgsStatic` 可构建并 portable 后恢复默认 | dc5d91f84032 | `manifests/default.nix`, `cmd/artifact/binary.go` |
| `tmux-plugins` | 📦 本地 | ❌ | 独立发布 `.tmux.conf` 数据 | 数据 bundle 是产品 | — | `packages/tmux-plugins/` |
| `uv` | 📌 `25.11` | ❌ | unstable 静态 darwin aws-lc-sys cc-wrapper `posix_spawn failed`；详见 manifest 注释 | 已确认必要，无可回归空间 | 624af665418d | `manifests/default.nix` |
| `vim` | 📦 本地 | ❌ | wrapper 相对设置 `VIMRUNTIME` | 可搬运 runtime 定位必须保留 | — | `packages/vim/` |
| `vim-plugins` | 📦 本地 | ❌ | 聚合固定 Vim plugins | plugin bundle 是产品 | — | `packages/vim-plugins/` |
| `watchexec` | 🩹 本地 | ✅ | `--package=watchexec-cli` 排除 test crate；darwin 仅 eval；详见 nix 注释 | stock 输出不含 `test-socketfd` 且只依赖系统库 | — | `packages/watchexec/` |
| `wget` | 🩹 + 📦 本地 | 🟡 | macOS 绕过 static Perl + CA wrapper；darwin 未验证；详见 nix 注释 | 恢复 checks/build tool 后保留 CA packaging | — | `packages/wget/` |
| `zsh` | 🩹 + 📦 本地 | 🟡 | 静态 module patches + FPATH wrapper/zshenv packaging；详见 nix 注释 | 逐项删编译 patch，保留 relocation packaging | — | `packages/zsh/` |
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
