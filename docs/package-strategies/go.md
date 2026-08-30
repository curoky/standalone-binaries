# Go 构建策略

Linux Go 工具默认使用 manifest 的 `pkgsStatic`。macOS 可选择 native CGO build，只要
最终产物仅依赖系统 dylib；不要为了“更静态”机械设置 `CGO_ENABLED=0`，因为这可能把
Go compiler store path 写入产物并触发 `disallowedReferences`。

## Darwin CGO Resolver

native Go/CGO 的 Nix `libresolv.9.dylib` 路径统一由
[`artifact`](../../cmd/artifact/AGENTS.md#darwin-cgo-resolver) 在严格检查 Mach-O 格式、
Go build info 和完整 dependency 路径后改指系统库，并保留 entitlement 重签。
新包仅有该问题时不再复制包级 `install_name_tool` override。

这不解决 `pkgsStatic` 编译失败，也不清理任意资源路径。`rclone` 仍必须在包级
`nuke-refs` 之前修正 resolver：hash 被抹掉后已不符合 artifact 的原始 Nix path 门禁。
不得为了迁移它而放宽公共匹配规则。

## Podman

Podman 必须绑定本仓库的静态 container helpers。尤其是 runc：上游 wrapper 是动态
launcher，而 Podman 的 helper collection 会复制该 launcher。`packages/podman/podman5.nix`
与 `packages/podman/podman6.nix` 因此直接安装真实静态 runc，并显式绑定 `conmon`、
`catatonit` 和 `crun`。

删除这层替换前，必须确认 Podman 收集到的是静态入口，而不是 `wrapProgram` launcher。
相关 helper 路径必须保持可搬运。

容器栈的 C 组件见 [C / autotools](c-autotools.md)。pin 和 patch 状态见
[回归清单](../regression/AGENTS.md)。
