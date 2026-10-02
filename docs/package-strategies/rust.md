# Rust 包

普通 Rust CLI 直接使用 unstable `pkgsStatic`。本地 derivation 只保留当前静态构建所需的
最小 override；状态见[回归清单](../regression/AGENTS.md)。

## 直接使用 Unwrapped 输出

`zellij` 直接构建 unstable `zellij-unwrapped`。上游 `zellij` 仅在注入额外 PATH 内容时提供
价值，本仓库不需要该 wrapper 层。

最终可执行文件仍必须通过 Linux musl 全静态校验。

## 构建工具链

Rust 依赖在 Linux musl cross 环境中应复用 build 平台可 substitute 的 glibc rustc/LLVM。
局部 overlay 不得修改 `buildPackages` 中的同名依赖；只针对 target 的 override 必须以
`stdenv.hostPlatform.isStatic` 限定。Node.js 中的 Rust 依赖遵守同一规则，见
[Node.js](nodejs.md)。
