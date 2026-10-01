# Node.js 构建策略

Node.js 仅在 Linux 发布，分为独立 runtime 和绑定同级 runtime 的 CLI 工具：

- runtime 是 musl 全静态；
- CLI 只发布 JS 和 wrapper，运行时显式执行同级 `nodejs-slim26`。

## Runtime

Node 构建需要 native Python 和平台构建工具；不要把 target 静态 Python 当 build tool。
需要 patch 内层依赖时使用局部 `pkgsStatic.extend`，并通过
`stdenv.hostPlatform.isStatic` 限制到 target 副本。否则 overlay 会污染
`buildPackages`，改变 cmake、LLVM 和 rustc 的 hash，导致大型工具链失去 binary cache。

使用 arch 对应的 musl cross static set（x86_64 用 musl64，aarch64 用
aarch64-multiplatform-musl），以便 Node 的 Rust 依赖复用 build 平台缓存工具链。

具体 patch 和禁用检查的状态见[回归清单](../regression/AGENTS.md)。

## CLI Wrapper

`packages/local/linux/node-tools.nix` 统一接入 Node CLI。wrapper 从自身路径定位：

```text
<store>/nodejs-slim26/bin/node
<store>/<tool>/libexec/<tool>/<entry>
```

因此运行时不依赖 shebang 或宿主 `node`。`prettier` 可在 build-time 使用静态
Node；需要 npm 的 `markdownlint-cli2` 和 `opencommit` 使用普通 Node 构建，只在运行时
切换到同级静态 runtime。`pnpm` 12 已是 Rust 原生程序，不属于 Node CLI。

新增 Node CLI 必须至少 smoke test shipped JS 在同级 runtime 上可执行。
