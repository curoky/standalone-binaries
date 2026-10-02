# macOS 回归表

<!-- markdownlint-disable MD013 -->

适用于 aarch64-darwin，记录该平台的包级定制和公共 workaround。表格约定、状态/定制图例与批量回归命令见
[`AGENTS.md`](AGENTS.md)。

Go/CGO 公共 resolver workaround 的原因、门禁和回归步骤由
[`cmd/artifact/AGENTS.md`](../../cmd/artifact/AGENTS.md#darwin-cgo-resolver) 维护。

| 包 | 定制 | 回归 | 原因与保留边界 | 回归判据 | commit | 来源 |
| ---------------------------- | -------------------- | -- | ------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------ | ------------ | ---------------------------------------------------------------------------------- |
| `7zz` | 📌 `gcc15-pin` | ✅ | 与 Linux 共用经全平台验证的 GCC 15 nixpkgs revision；当前 pin 的直接原因是 Linux 静态链接失败 | Darwin 用 unstable 构建且只动态链接系统库 | — | `manifests/default.nix`, `flake.nix` |
| `artifact-darwin-cgo-resolv` | 🩹 公共 artifact patch | ✅ | 修正 Go/CGO 的 Nix resolver load command | 按 artifact 文档绕过修正后，全部 consumer 无需替换 | — | `cmd/artifact/binary.go`, `cmd/artifact/binary_test.go`, `lib/make-artifacts.nix` |
| `aria2` | 📌 `24.11` + 📦 `bin` output | ❌ | unstable 静态 darwin 缺 iconv 符号链接失败；CLI 位于独立 `bin` output | pin 已确认必要；多 output 选择是发布边界 | 624af665418d | `manifests/default.nix` |
| `autoconf` | 📦 本地 | ❌ | 相对路径 wrappers 定位配套脚本 | 上游入口无需 Nix store 路径时再评估 | — | `packages/autoconf/` |
| `automake` | 📦 本地 | ❌ | 相对路径 wrappers 定位配套脚本 | 上游入口无需 Nix store 路径时再评估 | — | `packages/automake/` |
| `cloc` | 📦 本地 | 🟡 | sibling Perl 与模块 bundling；禁用 install check | 只恢复可运行的 install check | — | `packages/cloc/` |
| `colima` | 📦 native selection | ✅ | Darwin native；Go 资源仍含 store 引用 | 资源路径 portable 后恢复默认；resolver 独立回归 | dc5d91f84032 | `manifests/default.nix`, `cmd/artifact/normalize.go`, `cmd/artifact/binary.go` |
| `curl` | 📦 本地 | ❌ | 内置 CA bundle 与相对路径 wrapper | 自包含证书定位是 packaging | — | `packages/curl/` |
| `docker-buildx` | 📦 native selection | ✅ | native 绕过 static Go 缺 libresolv；resolver 由 artifact 修正 | `pkgsStatic` 可构建并 portable 后恢复默认 | dc5d91f84032 | `manifests/default.nix`, `cmd/artifact/binary.go` |
| `docker-compose` | 📦 native selection | ✅ | darwin native（pkgsStatic Go 缺 libresolv） | `pkgsStatic` 可构建并满足 portability 后恢复默认 | 624af665418d | `manifests/default.nix` |
| `exiftool` | 📦 本地 | 🟡 | sibling Perl 与压缩模块 bundling；禁用 install check | 仅上游可运行 install check 时恢复 | — | `packages/exiftool/` |
| `eza-ls` | 📦 本地 | ❌ | 自定义 `ls` 兼容层与 bundled eza | 独立产品行为，不是上游 bug | — | `packages/eza-ls/` |
| `ffmpeg` | 🩹 本地 | 🟡 | 静态 feature 裁剪、LAME/x265 修正、禁用 flaky FATE | 逐 feature 恢复且无 store 引用；LAME 不再漏 mpg123 后恢复 decoder；上游修 flaky 后恢复检查 | b4fd65b198c5 | `packages/ffmpeg/` |
| `file` | 🩹 + 📦 本地 | 🟡 | version check 直指真实二进制；wrapper 相对定位 `magic.mgc` | 上游检查可兼容 wrapper 后删除检查修正；资源定位必须保留 | b4fd65b198c5 | `packages/file/` |
| `git-filter-repo` | 📦 本地 | ❌ | Python sibling runtime；macOS 暂用宿主 Python | runtime packaging 不会因上游构建修复消失 | — | `packages/git-filter-repo/` |
| `ghostscript` | 🩹 本地 | ✅ | 与 Linux 共用静态 `gs` target override，避免上游固定的 shared `libgs` 构建路径 | `pkgsStatic.ghostscript_headless` 直接生成只依赖系统库的 `gs` 后删除 override | — | `packages/ghostscript/` |
| `poppler` | 🩹 + 📦 本地 | 🟡 | 静态依赖裁剪与链接修正；Darwin fontconfig/HarfBuzz 修正；相对资源包装 | static fontconfig、HarfBuzz 与 poppler-utils 可直接构建并通过测试后删除构建 workaround；可搬运资源打包保留 | — | `packages/poppler/` |
| `gnupg` | 📦 override | ❌ | 明确启用 minimal 并关闭 GUI | feature selection 是产品决策 | — | `packages/gnupg/` |
| `golangci-lint` | 📦 native selection | ✅ | native；resolver 由 artifact 修正 | `pkgsStatic` 可构建并 portable 后恢复默认 | dc5d91f84032 | `manifests/default.nix`, `cmd/artifact/binary.go` |
| `gost` | 📦 native selection | ✅ | native；resolver 由 artifact 修正 | `pkgsStatic` 可构建并 portable 后恢复默认 | dc5d91f84032 | `manifests/default.nix`, `cmd/artifact/binary.go` |
| `krb5` | 🩹 本地 | ❌ | 禁 CCAPI + 移 DES const（静态 darwin 两处 undefined symbol） | 上游修复 CCAPI/DES 静态可见性后删 patch | 624af665418d | `packages/krb5/` |
| `lark-cli` | 📦 native selection | ❌ | macOS 选 unstable native（关 CGO 反而 disallowed reference） | 当前没有 pin 或 patch 可回归 | — | `manifests/default.nix` |
| `libtool` | 📦 本地 | ❌ | 改写 `libtoolize` 的 baked data paths | 相对资源定位必须保留 | — | `packages/libtool/` |
| `lima` | 📦 native selection | ✅ | Darwin native；Go 资源仍含 store 引用 | 资源路径 portable 后恢复默认；resolver 独立回归 | dc5d91f84032 | `manifests/default.nix`, `cmd/artifact/normalize.go`, `cmd/artifact/binary.go` |
| `makeself` | 📦 本地 | ❌ | wrapper 相对定位 header 资源 | 可搬运资源定位必须保留 | — | `packages/makeself/` |
| `netron` | 📦 本地 | ❌ | wheel 重打包并绑定 sibling/宿主 Python | runtime packaging 必须保留 | — | `packages/netron/` |
| `nixfmt` | ⏸️ 停用 darwin | 🟡 | stock pkgsStatic macOS 编译失败，暂仅接入 Linux | macOS 构建修复后恢复 `aarch64-darwin` | — | `manifests/default.nix` |
| `pkgconf` | 🩹 本地 | ✅ | 改系统路径，避免二进制残留 store 路径 | stock 二进制不再嵌 store 路径且只依赖系统 dylib | — | `packages/pkgconf/` |
| `parallel` | 📦 本地 | ❌ | 多入口 sibling Perl wrappers | runtime packaging 必须保留 | — | `packages/parallel/` |
| `perl` | 🩹 + 📦 本地 | 🟡 | 静态依赖、相对 install name 与 wrapper | 只删除 stock 已覆盖的依赖/link patch | — | `packages/perl/` |
| `postgresql` | 🩹 + 📦 本地 | 🟡 | 基于 `pkgsStatic.libpq` 追加 psql，改系统 OpenSSL 目录 | `pkgsStatic.libpq` 上游提供 psql 且不嵌依赖路径 | dc5d91f84032 | `packages/postgresql/` |
| `radare2` | ⏸️ 停用 darwin | ❌ | 产品不要求 macOS 支持；仅在 Linux 包集合接入 | 产品边界，不作为上游回归目标 | — | `packages/local/linux/common.nix` |
| `rclone` | 📦 native selection | ✅ | Darwin native；保留三项 Go 资源 store 引用 | 资源路径 portable 后关闭；resolver 独立回归 | dc5d91f84032 | `manifests/default.nix`, `cmd/artifact/binary.go`, `docs/package-strategies/go.md` |
| `rime-plugins` | 📦 本地 | ❌ | 聚合多个 Rime 词库与转换结果 | 数据 bundle 是产品 | — | `packages/rime-plugins/` |
| `rizin` | ⏸️ 停用 darwin | ❌ | 产品不要求 macOS 支持；仅在 Linux 包集合接入 | 产品边界，不作为上游回归目标 | — | `packages/local/linux/common.nix` |
| `rsync` | 🩹 本地 | ✅ | 注入 native Python/check compiler + libiconv 指系统库 | stock 不再求值静态 Python、测试完整、不嵌 libiconv store 路径 | dc5d91f84032 | `packages/rsync/`, `packages/local/darwin.nix`, `manifests/default.nix` |
| `shellcheck` | 📌 `25.11` | ❌ | unstable 静态 darwin GHC External interpreter terminated | 已确认必要，无可回归空间 | 624af665418d | `manifests/default.nix` |
| `smartmontools` | 🩹 本地 | 🟡 | 关外部 drive DB + native autoreconfHook/hostname（避 static Perl） | static Perl 修复后删 build-tool override；CLI 配置保留 | dc5d91f84032 | `packages/smartmontools/darwin.nix`, `packages/local/darwin.nix` |
| `supercronic` | 📦 native selection | ✅ | native；resolver 由 artifact 修正 | `pkgsStatic` 可构建并 portable 后恢复默认 | dc5d91f84032 | `manifests/default.nix`, `cmd/artifact/binary.go` |
| `tmux-plugins` | 📦 本地 | ❌ | 独立发布 `.tmux.conf` 数据 | 数据 bundle 是产品 | — | `packages/tmux-plugins/` |
| `uv` | 📌 `25.11` | ❌ | unstable 静态 darwin aws-lc-sys cc-wrapper `posix_spawn failed` | 已确认必要，无可回归空间 | 624af665418d | `manifests/default.nix` |
| `vim` | 📦 本地 | ❌ | wrapper 相对设置 `VIMRUNTIME` | 可搬运 runtime 定位必须保留 | — | `packages/vim/` |
| `vim-plugins` | 📦 本地 | ❌ | 聚合固定 Vim plugins | plugin bundle 是产品 | — | `packages/vim-plugins/` |
| `wget` | 🩹 + 📦 本地 | 🟡 | native Perl build tool + CA wrapper | 恢复 checks/build tool 后保留 CA packaging | — | `packages/wget/` |
| `zsh` | 🩹 + 📦 本地 | 🟡 | 静态 module patches + FPATH wrapper + 相对 module path/zshenv packaging | 逐项删编译 patch，保留 relocation packaging | — | `packages/zsh/` |
| `zsh-plugins` | 📦 本地 | ❌ | 聚合 oh-my-zsh、plugins，并预生成 atuin/starship plugin | plugin bundle 与预生成 shell integration 是产品 | — | `packages/zsh-plugins/` |
