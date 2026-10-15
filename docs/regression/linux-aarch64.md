# ARM64 Linux platform exclusions

<!-- markdownlint-disable MD013 -->

本表记录 ARM64 Linux 的停用原因。该平台只选 stock 包，不维护本地修正；
两个 Linux 平台共用的 pin 见 [linux.md](linux.md)。字段含义见 [AGENTS.md](AGENTS.md)。

| 包 | 定制 | 回归 | 原因与保留边界 | 回归判据 | 已测 unstable | 来源 |
| --- | --- | --- | --- | --- | --- | --- |
| `bash` | ⏸️ 停用 aarch64 | 🟡 | stock unstable 带动态 ELF `lib/bash/accept`，不满足 Linux 纯静态产物约束 | stock artifact 不再包含动态 ELF 后恢复 | b4fd65b198c5 | `packages/upstream.nix` |
| `bat` | ⏸️ 停用 aarch64 | 🟡 | stock unstable 的 PCRE2 JIT 静态归档缺少 `__clear_cache`，ARM64 链接失败 | stock 包无需本地修正即可完成 artifact 构建后恢复 | 7fd4004d0511 | `packages/upstream.nix` |
| `coreutils` | ⏸️ 停用 aarch64 | 🟡 | stock unstable 带动态 ELF `libexec/coreutils/libstdbuf.so`，不满足 Linux 纯静态产物约束 | stock artifact 不再包含动态 ELF 后恢复 | b4fd65b198c5 | `packages/upstream.nix` |
| `dive` | ⏸️ 停用 aarch64 | 🟡 | unstable 的 `openldap` static 依赖找不到 Cyrus SASL | unstable 完整构建及 artifact 校验通过后恢复 | b4fd65b198c5 | `packages/upstream.nix` |
| `eza` | ⏸️ 停用 aarch64 | 🟡 | stock unstable 的 PCRE2 JIT 静态归档缺少 `__clear_cache`，ARM64 链接失败 | stock 包无需本地修正即可完成 artifact 构建后恢复 | 7fd4004d0511 | `packages/upstream.nix` |
| `git` | ⏸️ 停用 aarch64 | 🟡 | stock unstable 的 Rust `libgitcore.a` 引用 musl 不提供的 `*64` 符号；`26.05`、`25.11`、`25.05` stock 均失败于 `t2082` | 任一受支持 channel 的 stock 包完整构建及 artifact 校验通过后恢复 | b4fd65b198c5 | `packages/upstream.nix` |
| `git-absorb` | ⏸️ 停用 aarch64 | 🟡 | stock unstable 的 PCRE2 JIT 静态归档缺少 `__clear_cache`，ARM64 链接失败 | stock 包无需本地修正即可完成 artifact 构建后恢复 | 7fd4004d0511 | `packages/upstream.nix` |
| `imagemagick` | ⏸️ 停用 aarch64 | 🟡 | stock Potrace cross configure 误用 bundled getopt，且四项可选 delegate 静态构建失败；本地修正超出 upstream-only 边界 | stock ImageMagick 完整构建及 artifact 校验通过后恢复 | — | `packages/default.nix`, `packages/regression/imagemagick/` |
| `patchelf` | 📌 `25.05` + ⏸️ 停用 aarch64 | 🟡 | unstable checks 构建测试共享库时找不到 `-lbar` 与 `-lbar-scoped`；x86_64 仍走 `25.05` pin | unstable 完整构建及 artifact 校验通过后恢复 | b4fd65b198c5 | `packages/upstream.nix` |
| `pnpm` | ⏸️ 停用 aarch64 | ❌ | ARM64 Linux 不再作为 pnpm 的发布目标 | 重新纳入产品范围且 stock 包完整构建及 artifact 校验通过后恢复 | — | `packages/upstream.nix` |
| `python311` | ⏸️ 停用 aarch64 | 🟡 | stock unstable 带动态 ELF `lib-dynload/*.so`，不满足 Linux 纯静态产物约束 | stock artifact 不再包含动态 ELF 后恢复 | b4fd65b198c5 | `packages/upstream.nix` |
| `s6-dns` | ⏸️ 停用 aarch64 | 🟡 | 最新版需要本地 skaware pkg-config producer override，超出 upstream-only 边界 | stock 包无需本地 override 即可完整构建后恢复 | — | `packages/upstream.nix` |
| `s6-linux-utils` | ⏸️ 停用 aarch64 | 🟡 | 最新版需要本地 skaware pkg-config producer override，超出 upstream-only 边界 | stock 包无需本地 override 即可完整构建后恢复 | — | `packages/upstream.nix` |
| `s6-networking` | ⏸️ 停用 aarch64 | 🟡 | 最新版需要本地 skaware pkg-config producer override，超出 upstream-only 边界 | stock 包无需本地 override 即可完整构建后恢复 | — | `packages/upstream.nix` |
| `s6-portable-utils` | ⏸️ 停用 aarch64 | 🟡 | 最新版需要本地 skaware pkg-config producer override，超出 upstream-only 边界 | stock 包无需本地 override 即可完整构建后恢复 | — | `packages/upstream.nix` |
| `skalibs` | ⏸️ 停用 aarch64 | 🟡 | 最新版需要本地 skaware pkg-config producer override，超出 upstream-only 边界 | stock 包无需本地 override 即可完整构建后恢复 | — | `packages/upstream.nix` |
| `tesseract` | ⏸️ 停用 aarch64 | 🟡 | stock wrapper 归档后递归调用自身且 tessdata 路径失效；本地相对资源 packaging 超出 upstream-only 边界 | stock artifact 能以相对路径找到真实二进制和 tessdata 并完成 OCR 后恢复 | b4fd65b198c5 | `packages/default.nix`, `packages/tesseract/` |
