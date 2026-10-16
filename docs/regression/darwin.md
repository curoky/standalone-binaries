# macOS 回归表

<!-- markdownlint-disable MD013 -->

适用于 aarch64-darwin，记录该平台的包级定制和公共 workaround。表格约定、状态/定制图例与批量回归命令见
[`AGENTS.md`](AGENTS.md)。

Go/CGO 公共 resolver workaround 的原因、门禁和回归步骤由
[`cmd/artifact/AGENTS.md`](../../cmd/artifact/AGENTS.md#darwin-cgo-resolver) 维护。

| 包 | 定制 | 回归 | 原因与保留边界 | 回归判据 | 已测 unstable | 来源 |
| ---------------------------- | -------------------- | -- | ------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------ | ------------ | ---------------------------------------------------------------------------------- |
| `artifact-darwin-cgo-resolv` | 🩹 公共 artifact patch | ✅ | 修正 Go/CGO 的 Nix resolver load command | 按 artifact 文档绕过修正后，全部 consumer 无需替换 | — | `cmd/artifact/binary.go`, `cmd/artifact/binary_test.go`, `lib/make-artifacts.nix` |
| `aria2` | 📌 `24.11` + 📦 `bin` output | 🟡 | unstable 静态 darwin 缺 iconv 符号链接失败；CLI 位于独立 `bin` output | unstable 静态链接与 artifact 验证通过后删除 pin；保留 `bin` output | 624af665418d | `packages/upstream.nix` |
| `autoconf` | 📦 本地 | ❌ | 相对路径 wrappers 定位配套脚本 | 上游入口无需 Nix store 路径时再评估 | — | `packages/autoconf/` |
| `automake` | 📦 本地 | ❌ | 相对路径 wrappers 定位配套脚本 | 上游入口无需 Nix store 路径时再评估 | — | `packages/automake/` |
| `build-tool-splicing` | 🩹 公共 package-set patch | ✅ | Graphite2/rsync 的 build-only Python 和 wget 的 build-only Perl 强制使用 native package set，并门禁错误平台的 native inputs | 各 upstream producer 正确选择 native interpreter 后逐项删除 override；门禁保留 | — | `packages/static-build-tools.nix`, `lib/validate-native-build-inputs.nix` |
| `cloc` | 📦 本地 | 🟡 | sibling Perl 与模块 bundling；禁用 install check | 只恢复可运行的 install check | — | `packages/perlPackages/cloc.nix` |
| `colima` | 📦 native selection | ✅ | Darwin native；Go 资源仍含 store 引用 | 资源路径 portable 后恢复默认；resolver 独立回归 | dc5d91f84032 | `packages/upstream.nix`, `cmd/artifact/normalize.go`, `cmd/artifact/binary.go` |
| `curl` | 📦 本地 | ❌ | 内置 CA bundle 与相对路径 wrapper | 自包含证书定位是 packaging | — | `packages/curl/` |
| `dav1d` (imagemagick 内部) | 🩹 内部依赖 | ✅ | Darwin static Meson cross file 使用未知的 `arm64` CPU family，dav1d 误编译 ARM32 汇编；局部改为 Meson 标准的 `aarch64` | nixpkgs cross file 直接生成 `aarch64`，且 ImageMagick 完整 artifact 通过后删除 override | 7fd4004d0511 | `packages/regression/imagemagick/darwin.nix` |
| `docker-buildx` | 📦 native selection | ✅ | native 绕过 static Go 缺 libresolv；resolver 由 artifact 修正 | `pkgsStatic` 可构建并 portable 后恢复默认 | dc5d91f84032 | `packages/upstream.nix`, `cmd/artifact/binary.go` |
| `docker-compose` | 📦 native selection | ✅ | darwin native（pkgsStatic Go 缺 libresolv） | `pkgsStatic` 可构建并满足 portability 后恢复默认 | 624af665418d | `packages/upstream.nix` |
| `exiftool` | 📦 本地 | 🟡 | sibling Perl 与压缩模块 bundling；禁用 install check | 仅上游可运行 install check 时恢复 | — | `packages/perlPackages/` |
| `eza-ls` | 📦 本地 | ❌ | `ls` 命令行为与内置 eza | 独立产品行为，不是上游 bug | — | `packages/eza-ls/` |
| `ffmpeg` | 🩹 本地 | 🟡 | 静态 feature 裁剪、LAME/x265 修正、禁用 flaky FATE | 逐 feature 恢复且无 store 引用；LAME 不再漏 mpg123 后恢复 decoder；上游修 flaky 后恢复检查 | b4fd65b198c5 | `packages/ffmpeg/` |
| `file` | 🩹 + 📦 本地 | 🟡 | version check 直指真实二进制；wrapper 相对定位 `magic.mgc` | 上游检查可兼容 wrapper 后删除检查修正；资源定位必须保留 | b4fd65b198c5 | `packages/file/` |
| `fontconfig` (imagemagick 内部) | 🩹 内部依赖 | ✅ | Darwin static SDK 的 `locale_t` 与 `LC_*_MASK` 需要显式包含 `xlocale.h`；修正版递归注入 Cairo、Pango 和 librsvg | stock static fontconfig 可直接构建，且 ImageMagick 完整 artifact 通过后删除 override | 7fd4004d0511 | `packages/regression/imagemagick/darwin.nix` |
| `git-filter-repo` | 📦 本地 | ❌ | Python sibling runtime；macOS 暂用宿主 Python | runtime packaging 不会因上游构建修复消失 | — | `packages/pythonPackages/git-filter-repo.nix` |
| `ghostscript` | 🩹 本地 | ✅ | 与 Linux 共用静态 `gs` target override，避免上游固定的 shared `libgs` 构建路径 | `pkgsStatic.ghostscript_headless` 直接生成只依赖系统库的 `gs` 后删除 override | — | `packages/regression/ghostscript/` |
| `glib` (imagemagick 内部) | 🩹 内部依赖 | ✅ | Darwin static Meson cross file 使用未知的 `arm64` CPU family 且缺少 `macos` subsystem，GLib 无法完成平台检测；补齐标准值并递归注入所有 ImageMagick delegates | nixpkgs cross file 直接生成标准 CPU family/subsystem，且 ImageMagick 完整 artifact 通过后删除 override | 7fd4004d0511 | `packages/regression/imagemagick/darwin.nix` |
| `harfbuzz` (imagemagick 内部) | 🩹 内部依赖 | ✅ | 当前 macOS CoreText 会为 HarfBuzz 的诊断字体形成 `harfbuzz` 合字，与单个 in-house 用例的固定预期不符；仅从该用例移除 CoreText，保留 OpenType 断言及其余 CoreText 测试 | 该用例的 CoreText 预期适配当前系统行为，且 ImageMagick 完整 artifact 通过后删除 override | 7fd4004d0511 | `packages/regression/imagemagick/darwin.nix` |
| `imagemagick` | 🩹 + 📦 本地 | 🟡 | 关闭可选 FFTW，避开 static OpenMP 的 broken target Python；为 librsvg 的 GLib/libxml2/gettext 闭包补齐 Apple iconv 最终链接；嵌入 zero-configuration，并用相对 wrapper 打包 fontconfig 与最小 DejaVu 字体 | FFTW/OpenMP 可构建且 static librsvg 正确传播 iconv 后删除构建修正；保留可搬运配置、字体和 wrapper | 7fd4004d0511 | `packages/regression/imagemagick/darwin.nix` |
| `poppler` | 🩹 + 📦 本地 | 🟡 | 静态依赖裁剪与链接修正；Darwin fontconfig/HarfBuzz 修正；相对资源包装 | static fontconfig、HarfBuzz 与 poppler-utils 可直接构建并通过测试后删除构建 workaround；可搬运资源打包保留 | — | `packages/poppler/` |
| `golangci-lint` | 📦 native selection | ✅ | native；resolver 由 artifact 修正 | `pkgsStatic` 可构建并 portable 后恢复默认 | dc5d91f84032 | `packages/upstream.nix`, `cmd/artifact/binary.go` |
| `gost` | 📦 native selection | ✅ | native；resolver 由 artifact 修正 | `pkgsStatic` 可构建并 portable 后恢复默认 | dc5d91f84032 | `packages/upstream.nix`, `cmd/artifact/binary.go` |
| `krb5` | 🩹 本地 | ✅ | 禁 CCAPI + 移 DES const（静态 darwin 两处 undefined symbol） | 上游修复 CCAPI/DES 静态可见性后删 patch | 624af665418d | `packages/regression/krb5/` |
| `lark-cli` | 📦 native selection | ❌ | macOS 选 unstable native（关 CGO 反而 disallowed reference） | 当前没有 pin 或 patch 可回归 | — | `packages/upstream.nix` |
| `libheif` (imagemagick 内部) | 🩹 内部依赖 | ✅ | 示例/测试辅助库 `heifio` 自动发现 static libtiff，但后者导出的 CMake target 缺少 `Deflate::Deflate` 定义；仅关闭该辅助库的 TIFF 支持，并注入保留静态库的 x265 以启用 HEIC 编码 | libtiff CMake config 完整导入依赖、stock static x265 提供 library，且 ImageMagick 完整 artifact 通过后删除 override | 7fd4004d0511 | `packages/regression/imagemagick/darwin.nix` |
| `libraw` (imagemagick 内部) | 🩹 内部依赖 | ✅ | static libraw 的 C examples 用 C linker 链接 C++ 静态库，缺失 libc++ ABI 符号；ImageMagick 仅消费 library，局部关闭 examples | stock static libraw 可连同 examples 构建，且 ImageMagick 完整 artifact 通过后删除 override | 7fd4004d0511 | `packages/regression/imagemagick/darwin.nix` |
| `libtool` | 📦 本地 | ❌ | 改写 `libtoolize` 的 baked data paths | 相对资源定位必须保留 | — | `packages/libtool/` |
| `lima` | 📦 native selection | ✅ | Darwin native；Go 资源仍含 store 引用 | 资源路径 portable 后恢复默认；resolver 独立回归 | dc5d91f84032 | `packages/upstream.nix`, `cmd/artifact/normalize.go`, `cmd/artifact/binary.go` |
| `makeself` | 📦 本地 | ❌ | wrapper 相对定位 header 资源 | 可搬运资源定位必须保留 | — | `packages/makeself/` |
| `netron` | 📦 本地 | ❌ | wheel 重打包并绑定 sibling/宿主 Python | runtime packaging 必须保留 | — | `packages/pythonPackages/netron.nix` |
| `nixfmt` | ⏸️ 停用 darwin | 🟡 | stock pkgsStatic macOS 编译失败，暂仅接入 Linux | macOS 构建修复后恢复 `aarch64-darwin` | — | `packages/upstream.nix` |
| `pkgconf` | 🩹 本地 | ✅ | 改系统路径，避免二进制残留 store 路径 | stock 二进制不再嵌 store 路径且只依赖系统 dylib | — | `packages/pkgconf/` |
| `parallel` | 📦 本地 | ❌ | 多入口 sibling Perl wrappers | runtime packaging 必须保留 | — | `packages/perlPackages/parallel.nix` |
| `pango` (imagemagick 内部) | 🩹 内部依赖 | ✅ | Darwin static Meson cross file 使用未知的 `arm64` CPU family 且缺少 `macos` subsystem，Pango 无法完成平台检测；局部补齐标准值 | nixpkgs cross file 直接生成标准 CPU family/subsystem，且 ImageMagick 完整 artifact 通过后删除 override | 7fd4004d0511 | `packages/regression/imagemagick/darwin.nix` |
| `perl` | 🩹 + 📦 本地 | 🟡 | 静态依赖、相对 install name 与 wrapper | 只删除 stock 已覆盖的依赖/link patch | — | `packages/perlPackages/` |
| `postgresql` | 🩹 + 📦 本地 | 🟡 | 基于 `pkgsStatic.libpq` 追加 psql，改系统 OpenSSL 目录 | `pkgsStatic.libpq` 上游提供 psql 且不嵌依赖路径 | dc5d91f84032 | `packages/postgresql/` |
| `radare2` | ⏸️ 停用 darwin | ❌ | 产品不要求 macOS 支持；仅在 Linux 包集合接入 | 产品边界，不作为上游回归目标 | — | `packages/upstream.nix` |
| `rclone` | 📦 native selection | ✅ | Darwin native；保留三项 Go 资源 store 引用 | 资源路径 portable 后关闭；resolver 独立回归 | dc5d91f84032 | `packages/upstream.nix`, `cmd/artifact/binary.go`, `docs/package-strategies/go.md` |
| `rime-plugins` | 📦 本地 | ❌ | 聚合多个 Rime 词库与转换结果 | 数据 bundle 是产品 | — | `packages/rime-plugins/` |
| `rizin` | ⏸️ 停用 darwin | ❌ | 产品不要求 macOS 支持；仅在 Linux 包集合接入 | 产品边界，不作为上游回归目标 | — | `packages/default.nix` |
| `rsync` | 🩹 本地 | ✅ | 注入 native check compiler + libiconv 指系统库 | stock 测试完整且不嵌 libiconv store 路径 | dc5d91f84032 | `packages/regression/rsync/`, `packages/default.nix`, `packages/upstream.nix` |
| `shared-mime-info` (imagemagick 内部) | 🩹 内部依赖 | ✅ | `fetchFromGitLab` 解包源码导入 Darwin store 时，`calc.sct` 测试样本被系统拒绝读取；改用相同上游归档作为 flat fixed-output source | stock native/static `shared-mime-info` 源码可导入 store，且 ImageMagick 完整 artifact 通过后删除 source override | 7fd4004d0511 | `packages/regression/imagemagick/darwin.nix` |
| `shellcheck` | 📌 `25.11` | ✅ | unstable 静态 darwin GHC External interpreter terminated | unstable GHC 与 ShellCheck 可构建并通过 artifact 验证后删除 pin | 624af665418d | `packages/upstream.nix` |
| `smartmontools` | 🩹 本地 | 🟡 | 关外部 drive DB + native autoreconfHook/hostname（避 static Perl） | static Perl 修复后删 build-tool override；CLI 配置保留 | dc5d91f84032 | `packages/smartmontools/darwin.nix`, `packages/default.nix` |
| `supercronic` | 📦 native selection | ✅ | native；resolver 由 artifact 修正 | `pkgsStatic` 可构建并 portable 后恢复默认 | dc5d91f84032 | `packages/upstream.nix`, `cmd/artifact/binary.go` |
| `tesseract` | 🩹 + 📦 本地 | 🟡 | 去 training-only Pango 避免 static GLib 配置失败；同时链接 GNU/Apple iconv ABI 时仅隐藏 Apple archive 内重复的 `__libiconv_version`；相对路径 runtime 内置 `tessdata_best` 的 `eng`/`chi_sim`/`chi_tra`/`osd`，其他模型由外部 `TESSDATA_PREFIX` 提供 | static GLib/Pango 可构建且 iconv ABI 冲突消失后删 override；保留 Darwin runtime packaging | e12c65a91594 | `packages/tesseract/darwin.nix`, `packages/default.nix` |
| `tmux-plugins` | 📦 本地 | ❌ | 独立发布 `.tmux.conf` 数据 | 数据 bundle 是产品 | — | `packages/tmux-plugins/` |
| `vim` | 📦 本地 | ❌ | wrapper 相对设置 `VIMRUNTIME` | 可搬运 runtime 定位必须保留 | — | `packages/vim/` |
| `vim-plugins` | 📦 本地 | ❌ | 聚合固定 Vim plugins | plugin bundle 是产品 | — | `packages/vim-plugins/` |
| `wget` | 🩹 + 📦 本地 | 🟡 | 公共 native Perl build tool override + CA wrapper | upstream 正确选择 native Perl 后删公共 override；保留 CA packaging | — | `packages/static-build-tools.nix`, `packages/wget/` |
| `x265` (imagemagick 内部) | 🩹 内部依赖 | ✅ | stock `pkgsStatic.x265` 构建静态库后在 `postInstall` 主动删除全部 `.a`，libheif 因此只能启用 HEIC 解码；仅在 ImageMagick 依赖图保留 archive | stock static x265 保留 library，且 ImageMagick HEIC roundtrip artifact 验证通过后删除 override | 7fd4004d0511 | `packages/regression/imagemagick/darwin.nix` |
| `zsh` | 🩹 + 📦 本地 | 🟡 | 静态 module patches + FPATH wrapper + 相对 module path/zshenv packaging | 逐项删编译 patch，保留 relocation packaging | — | `packages/zsh/` |
| `zsh-plugins` | 📦 本地 | ❌ | 聚合 oh-my-zsh、plugins，并预生成 atuin/starship plugin | plugin bundle 与预生成 shell integration 是产品 | — | `packages/zsh-plugins/` |
