# Go 构建策略

Linux Go 工具默认使用 manifest 的 `pkgsStatic`。macOS 可选择 native CGO build，只要
最终产物仅依赖系统 dylib；不要为了“更静态”机械设置 `CGO_ENABLED=0`，因为这可能把
Go compiler store path 写入产物并触发 `disallowedReferences`。

## Darwin CGO Resolver

native Go/CGO 的 Nix `libresolv.9.dylib` 路径统一由
[`artifact`](../../cmd/artifact/AGENTS.md#darwin-cgo-resolver) 在严格检查 Mach-O 格式、
Go build info 和完整 dependency 路径后改指系统库，并保留 entitlement 重签。
新包仅有该问题时不再复制包级 `install_name_tool` override。

这不解决 `pkgsStatic` 编译失败，也不清理任意资源路径。不得用全量 `nuke-refs`
抹掉 resolver hash，也不得放宽公共匹配规则。

## Go 资源路径

nixpkgs 的 Go stdlib 补丁会内嵌 `tzdata`、`mailcap`、`iana-etc` 的 store 路径。
时区和 MIME 保留系统路径查找；IANA 补丁直接替换 `/etc/services` 和
`/etc/protocols`，不能假定也有文件路径 fallback。

将资源 hash 改成 `eeee...` 只会断开 Nix reference，不会恢复系统路径，也不能保证
功能完整。经用户确认，Darwin Rclone 已取消这种包级清理及配套 `disallowedReferences`，
改用 stock native；资源路径仍是已知缺口，不表示上游已修复或满足完整 portability。
有对应 Nix 数据的机器可能重新使用这些数据，无 Nix 环境则仍依赖既有系统/内置查询。
该决定不授权其他包放宽校验，也不改变动态库约束。

后续应在 Go 工具链构建层恢复标准资源路径，再重建 consumer；实施前需核对实际使用的
版本化 builder 和 build/target 边界。验证应覆盖未规范化的 source 引用，以及禁止读取
`/nix` 时的时区、MIME、DNS、服务名和协议名查询。当前状态见
[Rclone 资源路径](../regression/darwin.md#rclone-资源路径)。

## Podman

Podman 必须绑定本仓库的静态 container helpers。尤其是 runc：上游 wrapper 是动态
launcher，而 Podman 的 helper collection 会复制该 launcher。`packages/podman/podman5.nix`
与 `packages/podman/podman6.nix` 因此在 upstream 安装后解包真实静态 runc，并显式绑定 `conmon`、
`catatonit` 和 `crun`。

删除这层替换前，必须确认 Podman 收集到的是静态入口，而不是 `wrapProgram` launcher。
相关 helper 路径必须保持可搬运。

容器栈的 C 组件见 [C / autotools](c-autotools.md)。pin 和 patch 状态见
[回归清单](../regression/AGENTS.md)。
