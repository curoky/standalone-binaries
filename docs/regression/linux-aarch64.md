# Linux 回归表（aarch64 特有差异）

<!-- markdownlint-disable MD013 -->

`aarch64-linux` 是 upstream-only 的最小支持平台：只使用 `packages/upstream.nix` 选择的 raw
`pkgsStatic` 包，不应用 `packages/static-build-tools.nix`，也不导入 `packages/default.nix`。
本平台不维护 patch、override、wrapper 或结构性 repackaging；stock 包不能通过完整 artifact
流程时只在 manifest 中停用。下表仅记录这种平台停用差异，不建立 ARM64 patch 回归队列。
x86_64-linux 与 Darwin 的定制见各自表格。表格约定与图例见 [`AGENTS.md`](AGENTS.md)。

| 包 | 定制 | 回归 | 原因与保留边界 | 回归判据 | commit | 来源 |
| --- | --- | --- | --- | --- | --- | --- |
| `bash` | ⏸️ 停用 aarch64 | 🟡 | stock unstable 带动态 ELF `lib/bash/accept`，不满足 Linux 纯静态产物约束 | stock artifact 不再包含动态 ELF 后恢复 | b4fd65b198c5 | `packages/upstream.nix` |
| `coreutils` | ⏸️ 停用 aarch64 | 🟡 | stock unstable 带动态 ELF `libexec/coreutils/libstdbuf.so`，不满足 Linux 纯静态产物约束 | stock artifact 不再包含动态 ELF 后恢复 | b4fd65b198c5 | `packages/upstream.nix` |
| `dive` | 📌 `25.11` + ⏸️ 停用 aarch64 | 🟡 | unstable 的 `openldap` static 依赖找不到 Cyrus SASL；x86_64 仍走 `25.11` pin | unstable 完整构建及 artifact 校验通过后恢复 | b4fd65b198c5 | `packages/upstream.nix` |
| `git` | ⏸️ 停用 aarch64 | 🟡 | stock unstable 的 Rust `libgitcore.a` 引用 musl 不提供的 `*64` 符号；`26.05`、`25.11`、`25.05` stock 均失败于 `t2082` | 任一受支持 channel 的 stock 包完整构建及 artifact 校验通过后恢复 | b4fd65b198c5 | `packages/upstream.nix` |
| `patchelf` | 📌 `25.05` + ⏸️ 停用 aarch64 | 🟡 | unstable checks 构建测试共享库时找不到 `-lbar` 与 `-lbar-scoped`；x86_64 仍走 `25.05` pin | unstable 完整构建及 artifact 校验通过后恢复 | b4fd65b198c5 | `packages/upstream.nix` |
| `python311` | ⏸️ 停用 aarch64 | 🟡 | stock unstable 带动态 ELF `lib-dynload/*.so`，不满足 Linux 纯静态产物约束 | stock artifact 不再包含动态 ELF 后恢复 | b4fd65b198c5 | `packages/upstream.nix` |
| `s6-dns` | ⏸️ 停用 aarch64 | 🟡 | 最新版需要本地 skaware pkg-config producer override，超出 upstream-only 边界 | stock 包无需本地 override 即可完整构建后恢复 | — | `packages/upstream.nix` |
| `s6-linux-utils` | ⏸️ 停用 aarch64 | 🟡 | 最新版需要本地 skaware pkg-config producer override，超出 upstream-only 边界 | stock 包无需本地 override 即可完整构建后恢复 | — | `packages/upstream.nix` |
| `s6-networking` | ⏸️ 停用 aarch64 | 🟡 | 最新版需要本地 skaware pkg-config producer override，超出 upstream-only 边界 | stock 包无需本地 override 即可完整构建后恢复 | — | `packages/upstream.nix` |
| `s6-portable-utils` | ⏸️ 停用 aarch64 | 🟡 | 最新版需要本地 skaware pkg-config producer override，超出 upstream-only 边界 | stock 包无需本地 override 即可完整构建后恢复 | — | `packages/upstream.nix` |
| `skalibs` | ⏸️ 停用 aarch64 | 🟡 | 最新版需要本地 skaware pkg-config producer override，超出 upstream-only 边界 | stock 包无需本地 override 即可完整构建后恢复 | — | `packages/upstream.nix` |
| `tesseract` | ⏸️ 停用 aarch64 | 🟡 | stock wrapper 归档后递归调用自身且 tessdata 路径失效；本地相对资源 packaging 超出 upstream-only 边界 | stock artifact 能以相对路径找到真实二进制和 tessdata 并完成 OCR 后恢复 | b4fd65b198c5 | `packages/default.nix`, `packages/tesseract/` |
