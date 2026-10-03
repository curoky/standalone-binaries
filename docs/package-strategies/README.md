# 包构建策略

默认路径是在 `packages/upstream.nix` 选择 unstable `pkgsStatic`，再由
`cmd/artifact/` 完成 assembly、校验和归档。专题文档只解释不能从代码表面看出的
设计约束；具体包清单和回归状态分别以实现和[回归清单](../regression/AGENTS.md)为准。

`aarch64-linux` 只走这条默认路径，并直接使用 raw `pkgsStatic`；不应用本地 package-set
overlay，也不接入 `packages/default.nix`。该平台 stock 构建失败时在 manifest 中停用，
不进入下述本地 patch 或 packaging 路线。

| 生态 | 文档 | 主要案例 |
| --- | --- | --- |
| C / autotools | [c-autotools.md](c-autotools.md) | 静态链接、资源路径、s6 |
| Go | [go.md](go.md) | podman、macOS CGO |
| Java | [java.md](java.md) | 外部 JDK、包内 native 静态编译 |
| Node.js | [nodejs.md](nodejs.md) | Linux 静态 runtime、同级 Node wrapper |
| `pkgsStatic.extend` | [pkgsstatic-extend.md](pkgsstatic-extend.md) | target 与 build platform 边界 |
| Perl | [perl.md](perl.md) | 平台拆分解释器、纯 Perl 工具、XS 模块 |
| Python | [python.md](python.md) | 静态解释器、同级 Python wrapper |
| Rust | [rust.md](rust.md) |  |
| 特殊案例 | [special-cases.md](special-cases.md) | 非默认产物与动态例外 |

## 共用模式

### 相对资源 wrapper

把真实入口重命名为 `_<name>`，由 wrapper 根据自身路径定位资源。不要把 build-time
store path 写入 wrapper。

### 同级 runtime wrapper

wrapper 从自身路径求出共同 `store/` 目录，再显式执行同级 runtime。依赖包必须一起安装；
`bm` 不做依赖解析。

### 平台拆分

平台构建策略明显不同时，在对应 package 目录保存独立 derivation，例如
`linux.nix` 与 `darwin.nix`，再由 `packages/default.nix` 按目标平台选择，不在单个
derivation 文件堆叠条件。该机制只服务 `x86_64-linux` 与 `aarch64-darwin`；
`aarch64-linux` 不接入本地 derivation。

### 状态管理

pin、patch、禁用检查、linker workaround、结构性 packaging 和动态例外只在
[回归清单](../regression/AGENTS.md)维护状态。专题文档不复制回归队列或测试历史。
包级 root cause、对应修正和保留边界写在最终 derivation 的 Nix 文件头部；回归表只留
一句候选摘要与删除判据，选择/接线文件只保留分组标题。
