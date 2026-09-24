# Go 构建策略

Linux Go 工具默认使用 manifest 的 `pkgsStatic`。macOS 可选择 native CGO build，只要
最终产物仅依赖系统 dylib；不要为了“更静态”机械设置 `CGO_ENABLED=0`，因为这可能把
Go compiler store path 写入产物并触发 `disallowedReferences`。

## Go Compiler

`go` 只在 Linux 发布，使用 unstable 的 `pkgsStatic.go_latest` 从源码构建完整 SDK。编译器
和内部工具本身是 musl 静态 ELF，但公开默认值与官方 Linux Go 对齐：native build 自动
探测 CGO，C/C++ compiler 是 `gcc` / `g++`，external linking 保持 auto，动态 loader 不固定
为 Nix 构建机的 musl loader，`GO386` 默认 `sse2`。与官方安装相同，使用 CGO 或 race 时
需要宿主另行提供 GCC。

nixpkgs 的 Go 补丁会改变资源查找、vendor 校验、GOTOOLDIR 和动态 loader 行为，因此这个
SDK 不应用这些补丁。`cmd/dist` 在完整 bootstrap 期间直接生成官方默认配置，避免把 Nix
cross compiler 名称和构建期 musl loader 带入最终 SDK。静态构建的 linker 不能自动识别
bundled race object 必须外链，因此仅对 `-race` 强制 external linking；普通纯 Go 交叉编译
仍保持官方的 auto 行为。

SDK 保留 `bin`、`src`、`pkg/tool`、`lib` 等标准 GOROOT 内容，让 `cmd/go` 能从搬迁后的
`bin/go` 自动推导 GOROOT。`debug/dwarf` 与 `debug/elf` 的标准库 testdata 含故意构造的
glibc-dynamic ELF fixtures，既不参与编译器运行，也不应放宽 artifact 的 ELF 门禁，因此
由 `packages/go` 在安装期移除。

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

per-user rootless API 作为独立的 `podman5-rootless` / `podman6-rootless` bundle
发布。它是对应 rootful bundle 的薄 overlay，只替换 rootless 专属 wrapper 和 s6-rc service；
持久数据使用 bundle 相对路径，易失状态与 socket 位于 `/run`。完整产品边界见
[`packages/podman-rootless/DESIGN.md`](../../packages/podman-rootless/DESIGN.md)。

容器栈的 C 组件见 [C / autotools](c-autotools.md)。pin 和 patch 状态见
[回归清单](../regression/AGENTS.md)。
