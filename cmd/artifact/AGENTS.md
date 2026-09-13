# Artifact Agent Guide

`cmd/artifact/` 是所有包共享的后处理与归档工具，由
`lib/make-artifacts.nix` 调用。全局产物约束见根
[`AGENTS.md`](../../AGENTS.md)；本文件定义该组件的行为边界。

## 输入与输出

工具接收 source package tree、standalone output、tar.gz output、artifact name 和
目标平台。`lib/make-artifacts.nix` 为每个包创建同一个 multi-output derivation：

- `out`：规范化后的 standalone 目录；
- `archive`：以 artifact name 为顶层目录的确定性 tar.gz。

Artifact name 必须是安全的相对路径。Archive 固定 uid、gid、时间戳和 header metadata，
保证相同输入生成相同归档。

## 规范化

- 删除 `nix-support`、man page、文档、shell completion、`.a` 和 `.pyc`。
- 保留内部 symlink，物化外部 symlink，删除 dangling symlink。
- 恢复 `.*-wrapped` 入口。
- 文本 shebang 改为 `/usr/bin/env`，删除文本中的 Nix store binary path。
- Linux ELF 执行 strip；二进制中的 store hash 被稳定替换。
- Darwin Mach-O 删除 Nix rpath；Go CGO resolver 的有限修正规则见下文。
- 统一目录和文件权限，再生成归档。

Artifact 只做规范化与约束校验，不会把动态程序变成静态程序，也不会推断任意硬编码资源
路径。此类问题必须在 package derivation 中修复。

### Darwin CGO Resolver

只有以下条件全部满足，才把 Nix resolver dependency 改为
`/usr/lib/libresolv.9.dylib`：

- artifact 平台为 Darwin，文件为 thin arm64 Mach-O executable；
- Go build info 明确包含 `GOOS=darwin`、`GOARCH=arm64`、`CGO_ENABLED=1`、
  `-compiler=gc`，且 `-buildmode` 为 `exe` 或 `pie`；
- dependency 完整匹配 `/nix/store/<32 位 Nix hash>-libresolv-<数字版本>/lib/libresolv.9.dylib`。

这是已知 Apple resolver ABI 的路径修正，不是通用系统库替换。缺少 build info、非 Go、
纯 Go、fat binary、其他架构、dylib 和其他库名/ABI 均不启用；未改写的不合规 dependency
仍由原有校验拒绝。已有系统依赖保持不变，不执行无必要的 `install_name_tool` 或重签名。

所有 Mach-O load-command 修改（包括原有 Nix rpath 删除）完成后，调用 Darwin 系统
`/usr/bin/codesign` 做无时间戳的 ad-hoc 重签；已有签名保留 identifier、entitlements、
flags 和 runtime，尤其不能丢失 Lima 的 virtualization entitlement。不使用无法保留这些
metadata 的 nixpkgs sigtool 0.1.3。此依赖只用于构建，不引入产物运行时依赖。

resolver 替换是临时 workaround，以 `artifact-darwin-cgo-resolv` 独立进入
[回归队列](../../docs/regression/darwin.md#darwin-cgo-resolver-回归)。nixpkgs 更新后必须
在绕过该替换的条件下重新评估；普通 artifact / probe 成功不算移除依据。删除 resolver
特例时保留通用 Nix rpath 清理及必要重签。

## Binary Validation

- 只检查当前构建平台的原生格式：Linux 检查 ELF，Darwin 检查 Mach-O。打包的跨平台
  binary 不得触发另一平台工具链。
- Linux ELF 默认必须静态链接；`music-decrypto` 和 `nsight-systems` 由
  `lib/make-artifacts.nix` 显式传入动态例外。
- Darwin dependency 只允许 `/usr/lib`、`/System/Library/Frameworks`、
  `@loader_path` 和 `@rpath`。
- Darwin rpath 必须是 `@loader_path` 或其子路径；`/nix` load command 一律失败。
- 原生 ELF 或 Mach-O 无法解析时 fail-closed。
- 路径含 `openssl` 的文件保留既有 validation 豁免，但仍执行格式相关清理。

不要通过放宽全局校验修复单包问题。新增动态例外或改变 `openssl` 豁免前先确认，并同步
`lib/make-artifacts.nix`、[回归清单](../../docs/regression/AGENTS.md) 和
根 [`AGENTS.md`](../../AGENTS.md)。

## 实现边界

- `main.go`：参数、平台和调用顺序。
- `normalize.go`：tree 复制、裁剪、symlink、文本和 binary 规范化。
- `binary.go`：ELF/Mach-O inspection 与 portability validation。
- `archive.go`：确定性 tar.gz。
- `main_test.go`：规范化、格式识别、校验与归档行为。
- `binary_test.go`：CGO resolver 严格门禁、签名、幂等性和 Darwin native smoke tests；
  平台无关的合成 fixture 测试在 Linux 也运行，native smoke tests 需要 Darwin arm64、
  Go、clang、cctools 和系统 codesign。

保持标准库实现，不增加外部运行时依赖。修改归档顶层目录、metadata 或 binary policy
时，同步 `lib/make-artifacts.nix`、[`cmd/binman/AGENTS.md`](../binman/AGENTS.md)
和发布 workflow。

## 验证

```bash
CGO_ENABLED=0 go test ./cmd/artifact
CGO_ENABLED=0 go vet ./cmd/artifact
CGO_ENABLED=0 go build ./cmd/artifact
```
