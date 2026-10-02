# Linux 回归表（aarch64 特有差异）

<!-- markdownlint-disable MD013 -->

仅列 aarch64-linux 与共享 [`linux.md`](linux.md) 的差异。当前都是「临时停用」（⏸️）：这些包的
musl-static cross 构建目前在 aarch64-linux 失败，已在 manifest 或本地包集里去掉该架构，等上游/工具链
修复后恢复。x86_64-linux 与 darwin 的状态见各自表格。表格约定与图例见 [`AGENTS.md`](AGENTS.md)。

| 包 | 定制 | 回归 | 原因与保留边界 | 回归判据 | commit | 来源 |
| --- | --- | --- | --- | --- | --- | --- |
| `bash` | ⏸️ 停用 aarch64 | 🟡 | stock unstable 带动态 ELF `lib/bash/accept`，不满足 Linux 纯静态产物约束 | stock artifact 不再包含动态 ELF 后恢复 | b4fd65b198c5 | `manifests/default.nix` |
| `coreutils` | ⏸️ 停用 aarch64 | 🟡 | stock unstable 带动态 ELF `libexec/coreutils/libstdbuf.so`，不满足 Linux 纯静态产物约束 | stock artifact 不再包含动态 ELF 后恢复 | b4fd65b198c5 | `manifests/default.nix` |
| `dive` | 📌 `25.11` + ⏸️ 停用 aarch64 | 🟡 | unstable 的 `openldap` static 依赖找不到 Cyrus SASL；x86_64 仍走 `25.11` pin（详见 `linux.md`） | unstable 完整构建及 artifact 校验通过后恢复 | b4fd65b198c5 | `manifests/default.nix` |
| `git` | 🩹 x86_64 本地 + ⏸️ 停用 aarch64 | 🟡 | unstable 的 Rust `libgitcore.a` 引用 musl 不提供的 `*64` 符号；`26.05`、`25.11`、`25.05` stock 均失败于 `t2082` | 任一受支持 channel 无 patch 完整构建及 artifact 校验通过后恢复 | b4fd65b198c5 | `packages/local/linux/x86_64.nix`, `packages/git/` |
| `patchelf` | 📌 `25.05` + ⏸️ 停用 aarch64 | 🟡 | unstable checks 构建测试共享库时找不到 `-lbar` 与 `-lbar-scoped`；x86_64 仍走 `25.05` pin（详见 `linux.md`） | unstable 完整构建及 artifact 校验通过后恢复 | b4fd65b198c5 | `manifests/default.nix` |
| `python311` | 📦 x86_64 本地 + ⏸️ 停用 aarch64 | 🟡 | stock unstable 带动态 ELF `lib-dynload/*.so`，不满足 Linux 纯静态产物约束 | stock artifact 不再包含动态 ELF 后恢复 | b4fd65b198c5 | `packages/local/linux/x86_64.nix`, `packages/python/` |
