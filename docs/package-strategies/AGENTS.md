# Package builds

本目录说明构建方式和运行边界。接入、修复及删除定制按
[maintain-packages](../../.agents/skills/maintain-packages/SKILL.md) 执行；
当前平台支持见[支持表](../packages.md)，待移除的修正见[定制记录](../regression/AGENTS.md)。

## Package sets

[`lib/make-system-outputs.nix`](../../lib/make-system-outputs.nix) 选择构建环境：

| 平台 | 静态 package set | 本地包与 build-tool 修正 |
| --- | --- | --- |
| `x86_64-linux` | `pkgsCross.musl64.pkgsStatic` | 启用 |
| `aarch64-linux` | `pkgsCross.aarch64-multiplatform-musl.pkgsStatic` | 禁用 |
| `aarch64-darwin` | 原生 `pkgsStatic` | 启用 |

Linux target 使用 musl，build tools 可复用 glibc 工具链。
正式包递归检查 native input 的 host platform 是否等于 consumer 的 build platform。
构建期工具选择和局部 overlay 见 [Build tools](build-tools.md)。

Manifest schema 见 [`packages/upstream.nix`](../../packages/upstream.nix)，校验由
[`lib/make-manifest-packages.nix`](../../lib/make-manifest-packages.nix) 实现。
未知字段、平台、channel、错误类型以及空或重复 output 必须在 eval 时失败。

## Local packages

- 在 `packages/<name>/` 保存定制，通过 `packages/default.nix` 显式接入。
  平台处理明显不同时拆成 `linux.nix` / `darwin.nix`。
- 共享工具链或 runtime 的包可共用目录，不再增加子级 index。
  `packages/regression/<name>/` 收纳有望由 nixpkgs 修复替代的构建或依赖 workaround，
  可包含需要逐项回归的修正；文件头说明可上游的部分。产品 wrapper、资源布局和功能配置
  留在对应包目录。
- 只有面向独立使用的工具才返回到包集合。仅供其他包使用的库和 helper 在
  `packages/default.nix` 的 `let` 中接线，随消费方构建，不生成独立 artifact。
- 资源 wrapper 根据自身路径定位真实入口、数据和 helper；同级 runtime wrapper 根据
  自身路径定位共同 `store/`。不要依赖构建期绝对路径。
- Artifact 负责整理、校验和归档；包的功能、资源路径和链接问题在 derivation 中修复。

## Topics

只读与本次改动有关的专题。

| 问题 | 文档 |
| --- | --- |
| 静态链接、CA、资源路径、s6 | [C / autotools](c-autotools.md) |
| native input、splicing、Rust/LLVM 缓存、局部 overlay | [Build tools](build-tools.md) |
| Go SDK、CGO、资源路径 | [Go](go.md) |
| 外部 JDK、JAR 与 native helper | [Java](java.md) |
| 静态 Node 与 JS wrapper | [Node.js](nodejs.md) |
| Perl runtime、XS 与 wrapper | [Perl](perl.md) |
| CPython 静态扩展与 wrapper | [Python](python.md) |
| 裁剪输出、动态库和宿主依赖例外 | [产物边界](special-cases.md) |

## Probe

```bash
nix build .#probe.<system>.<channel>.<attr>
```

Probe 从锁定 channel 的 raw `pkgsStatic` 取顶层 attr，走完整 artifact 流程；绕过
manifest、本地包、`static-build-tools.nix` 和 native-input 检查。
因此 probe 成功后仍要验证正式输出；probe 失败也可能是正式 build-tool 修正已解决的问题。
它仍执行 artifact 公共修正，不能据此证明公共修正可删除。

Channel 名见 `flake.nix`；probe 路径去掉版本号中的点，如 `25.11` 写作 `2511`。
带点的嵌套 attr 不支持此入口，改用一次性 Nix 表达式或正式接线验证。
