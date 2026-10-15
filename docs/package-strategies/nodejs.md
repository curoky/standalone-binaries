# Node.js 构建策略

Node.js runtime 和 JS CLI 仅在 x86_64 Linux 发布：

- runtime 是 musl 全静态；
- CLI 只发布 JS 和 wrapper，运行时显式执行同级 `nodejs-slim26`。

## Runtime

Node 需要 native Python 和构建工具，Rust 依赖复用 build 平台工具链。
修改内层依赖时按 [Build tools](build-tools.md) 限制局部 overlay 的作用范围。

具体 patch 和禁用检查的状态见[回归清单](../regression/AGENTS.md)。

## CLI Wrapper

`packages/default.nix` 从 `packages/nodejsPackages/` 统一接入 Node CLI。wrapper 从自身路径定位：

```text
<store>/nodejs-slim26/bin/node
<store>/<tool>/libexec/<tool>/<entry>
```

因此运行时不依赖 shebang 或宿主 `node`。`prettier` 可在 build-time 使用静态
Node；需要 npm 的 `markdownlint-cli2` 和 `opencommit` 使用普通 Node 构建，只在运行时
切换到同级静态 runtime。`pnpm` 12 已是 Rust 原生程序，不属于 Node CLI。

新增 Node CLI 必须至少 smoke test shipped JS 在同级 runtime 上可执行。
