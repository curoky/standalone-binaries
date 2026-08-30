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
| `colima` | 📦 本地 | ❌ | darwin-only；只打本体，删除 stock PATH wrapper，lima/qemu/docker 按本仓库模型单独安装并由用户 PATH 解析；completion 保留。resolver 修正已移至 artifact 严格门禁；0.10.3 构建、依赖检查、签名和 version smoke test 通过，未启动 VM | 独立运行时依赖与无 store PATH 的 packaging 保留 | dc5d91f84032 | `packages/colima/`, `cmd/artifact/binary.go` |
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
| `lima` | 📦 本地 | ❌ | darwin-only；保留宿主 limactl、helpers、guest agents/templates；删除 stock qemu PATH wrapper，运行时依赖单独安装。resolver 修正和重签已移至 artifact 严格门禁。2.2.0 最终 artifact 与 tarball 构建通过，三个宿主 Mach-O 只依赖系统库且签名有效，limactl 保留 virtualization/network entitlements；wrapper、version 和 template copy smoke test 通过，未启动 VM | 独立运行时依赖、guest agents/templates 与 entitlement 保留 | dc5d91f84032 | `packages/lima/`, `cmd/artifact/binary.go` |
| `makeself` | 📦 本地 | ❌ | wrapper 相对定位 header 资源 | 可搬运资源定位必须保留 | — | `packages/makeself/` |
| `markdownlint-cli2` | 📦 本地 | ❌ | JS 分发绑定 sibling Node runtime | sibling runtime packaging 必须保留 | — | `packages/markdownlint-cli2/` |
| `music-decrypto` | 🩹 ICU 路径 | 🟡 | macOS 可回归系统 ICU patch | macOS stock 仅用系统 dylib | — | `packages/music-decrypto/` |
| `netron` | 📦 本地 | ❌ | wheel 重打包并绑定 sibling/宿主 Python | runtime packaging 必须保留 | — | `packages/netron/` |
| `nixfmt` | ⏸️ 停用 darwin | 🟡 | stock `pkgsStatic` 构建在 macOS 上编译失败，暂时仅接入 Linux（两平台均走零定制 manifest pkgsStatic）| macOS 构建修复后恢复 `aarch64-darwin` | — | `manifests/default.nix` |
| `nodejs-slim26` | 🩹 本地 | 🟡 | 修 static deps、LIEF/Temporal、system libs 和 checks；macOS 注入 build tools，darwin 未验证 | 逐 patch 删除，最终满足各平台动态依赖规则 | — | `packages/nodejs/26/` |
| `opencommit` | 📦 本地 | ❌ | JS 分发绑定 sibling Node runtime | sibling runtime packaging 必须保留 | — | `packages/opencommit/` |
| `p7zip` | 🩹 本地 | 🟡 | 强制 default build flags；output 布局为 packaging，darwin 未验证 | stock build 可用时删 build workaround，保留所需 outputs | — | `packages/p7zip/` |
| `pkgconf` | 🩹 本地 | ✅ | stock `pkgconf-unwrapped` 把自身 Nix output 的 `.pc`、system lib/include 与 personality 路径编译进二进制；本地 override 改用标准 `/usr` 与 `/usr/local` 路径，避免 standalone 产物残留 `/nix/store` | stock 二进制不再编译进 Nix store 路径且只依赖系统 dylib | — | `packages/pkgconf/` |
| `parallel` | 📦 本地 | ❌ | 多入口 sibling Perl wrappers | runtime packaging 必须保留 | — | `packages/parallel/` |
| `perl` | 🩹 + 📦 本地 | 🟡 | macOS 静态替换与 install-name relocation；wrapper 必须保留，darwin 未验证 | 只删除 stock 已覆盖的依赖/link patch | — | `packages/perl/` |
| `pnpm` | 📦 本地 | ❌ | JS 分发绑定 sibling Node runtime | sibling runtime packaging 必须保留 | — | `packages/pnpm/` |
| `prettier` | 📦 本地 | ❌ | JS 分发绑定 sibling Node runtime | sibling runtime packaging 必须保留 | — | `packages/prettier/` |
| `protobuf_3_8_0` | 📌 源码版本 | ❌ | 明确发布 legacy protobuf 3.8.0 | 版本化产品，不回到最新 upstream | — | `packages/protobuf/3_8_0/` |
| `protobuf_3_9_2` | 📌 源码版本 | ❌ | 明确发布 legacy protobuf 3.9.2 | 版本化产品，不回到最新 upstream | — | `packages/protobuf/3_9_2/` |
| `rclone` | 🩹 本地 | 🟡 | 仅 darwin 有定制（Linux 走零定制 manifest pkgsStatic 全静态）；postInstall 先将 resolver 改指系统库，再用 `nuke-refs` 清理 tzdata/mailcap/iana-etc fallback store hash。该顺序必须保留：若先 nuke，原始 resolver hash 被抹掉，无法命中 artifact 的严格门禁；本轮未迁移或重建此包 | stock native 只链接系统 dylib且不内嵌真实 store 路径，或 `pkgsStatic` 可直接构建并满足 macOS portability 后删除 override | b7c2ada94fe9 | `packages/rclone/` |
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

## Darwin CGO Resolver 回归

`artifact-darwin-cgo-resolv` 是公共组件候选 ID，不是可构建的 package attr。
每次 nixpkgs bump 后，按该行的 commit 和通用队列规则重新评估；不能因包级 patch 已删除
或 `colima` / `lima` 的 packaging 行标为结构性保留而跳过它。

1. 从当前 flake 的 `sources.aarch64-darwin` 核对实际使用的 source 和 Go toolchain，
   检查未经过 artifact 的宿主 Mach-O，包括 `bin`、`libexec` 和其他随包 helper。
   初始验证集至少包含 `gost`、`supercronic`、`golangci-lint`、`docker-buildx`、
   `colima`、`lima`；同时纳入当前 source 中新发现的 Go/CGO resolver consumer。
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
   native selection 的回归独立进行；`rclone` 的包级 resolver / `nuke-refs` 顺序仍按其
   自身候选验证，不随公共 patch 一并删除。
