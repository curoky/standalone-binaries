# Go

Linux 默认使用静态 package set。macOS 可选 native CGO，只要最终动态依赖满足
[产物边界](special-cases.md)。关闭 CGO 前验证功能和 store 引用；不要把它当作通用修复。

## Build tools

x86_64 Linux 的默认及版本化 `buildGoModule` 使用 build-platform Go，只删除 nixpkgs
注入 `tzdata`、`mailcap`、`iana-etc` 路径的三个 compiler patch，其余保持上游行为。
实现见 [`static-build-tools.nix`](../../packages/static-build-tools.nix)。
ARM64 Linux 和 probe 使用 raw package set。

## Go SDK

[`packages/go/`](../../packages/go/default.nix) 发布 musl 静态 SDK，保留标准 GOROOT 布局，
从搬迁后的 `bin/go` 定位资源。公开默认行为与官方 Linux Go 对齐：native 自动探测 CGO，
使用宿主 `gcc` / `g++`，普通 external linking 为 auto，race 强制外链。
使用 CGO 或 race 需要宿主 GCC。修改 bootstrap 默认值时同时验证纯 Go、CGO 和 race。

## Darwin CGO resolver

原生 Go/CGO 的特定 Nix resolver 路径由
[artifact](../../cmd/artifact/AGENTS.md#darwin-cgo-resolver) 统一修正；新包仅有该问题时
不添加包级 `install_name_tool`。此修正不处理编译失败或任意资源路径。

## Resource paths

nixpkgs Go stdlib patch 会嵌入三类资源 store 路径。时区和 MIME 保留系统查找路径；
IANA patch 直接替换 `/etc/services`、`/etc/protocols`。把 hash 改成占位字符不会恢复
标准查询行为。

Darwin Rclone 的资源引用按[已知缺口](special-cases.md#known-gap) 保留。
修复应在实际使用的 Go builder 恢复标准路径后重建 consumer；检查未规范化的 source
引用，并在禁止读取 `/nix` 的条件下测试时区、MIME、DNS、服务名和协议名查询。

## Podman

Podman 收集的 helpers 必须是实际静态入口，包括解开 nixpkgs wrapper 后的 runc。
相对路径与服务行为见 [Podman](../../packages/podman/AGENTS.md) 和
[Rootless Podman](../../packages/podman-rootless/AGENTS.md)。
