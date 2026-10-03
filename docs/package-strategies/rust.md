# Rust 包

普通 Rust CLI 直接使用 unstable `pkgsStatic`。本地 derivation 只保留当前静态构建所需的
最小 override；状态见[回归清单](../regression/AGENTS.md)。

## 构建工具链

Rust 依赖在 Linux musl cross 环境中应复用 build 平台可 substitute 的 glibc rustc/LLVM。
局部 overlay 不得修改 `buildPackages` 中的同名依赖；只针对 target 的 override 必须以
`stdenv.hostPlatform.isStatic` 限定。Node.js 中的 Rust 依赖遵守同一规则，见
[Node.js](nodejs.md)。
