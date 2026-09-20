# Podman Agent Guide

本目录构建 `podman5` 与 `podman6` 的 rootful standalone bundle。安装、目录与宿主接口见
[`DESIGN.md`](DESIGN.md)；rootless 差异见
[`../podman-rootless/AGENTS.md`](../podman-rootless/AGENTS.md)。

## Invariants

- 两版共用 `bin/`、`conf/`、patch 与 tests；版本差异留在 `podman5.nix` 和
  `podman6.nix`，不再抽一层 builder。
- `_podman` 是内部静态二进制，`podman`/`docker` 是固定 rootful socket 的 remote client，
  `podman-server` 是唯一 local engine 入口。
- 所有持久状态相对 bundle，所有 boot-sensitive 状态位于 `/run/podman`。不要增加宿主
  `/etc/containers`、用户 XDG 配置或 PATH helper fallback。
- 产品策略只写在共享 `conf/containers.conf` 与 `conf/storage.conf`。wrapper 只负责动态绝对
  路径、隔离外部 override，以及无法写入 TOML 的 `default-mounts-file`。
- helper 使用 `helper_binaries_dir = ["$BINDIR/../libexec/podman"]`；conmon 和 OCI runtime
  通过仅含同目录的 PATH 解析。新增 helper 时必须保持这条边界。
- 修改 patch 前先证明配置或环境变量能产生完全相同的运行行为。当前源码 patch 只解决
  配置无法表达的行为：固定内置 seccomp、固定 catatonit、registry drop-in 隔离，以及
  Podman 5 的 signature policy 环境变量。
- runc 必须复制真实静态 ELF，不能复制 nixpkgs 的动态 wrapper。所有常规 ELF 继续满足
  musl-static 与无 `/nix/store` 运行时引用。

## Validation

修改共享配置、wrapper 或 patch 后至少构建 `podman5`、`podman6` 及对应 tarball。
install check 必须覆盖 bundle 搬迁、配置与环境隔离、helper 解析、registry/policy/seccomp、
rootful systemd 安装和主要 helper 的 version smoke。涉及真实容器、网络或 cgroup 行为时，
另在具备 cgroup v2、namespace 与 nftables 权限的 Linux 环境验证。
