# Rootless Podman Agent Guide

本目录生成 `podman5-rootless` 与 `podman6-rootless`。安装、目录、重启与宿主依赖见
[`DESIGN.md`](DESIGN.md)；继承的 Podman 策略见
[`../podman/AGENTS.md`](../podman/AGENTS.md)。

## Invariants

- rootless bundle 必须是对应 rootful 输出的薄 overlay，只替换 wrapper、installer、s6-rc
  service，删除 systemd unit 与 rootful bridge。共享二进制和配置不得复制维护。
- 一份 bundle 只服务一个普通用户。持久状态相对 bundle，运行态固定在
  `/run/user/<uid>/podman`；目录名和 bundle 内文件名不附加 `rootless` 或 `user` 后缀。
- 使用 s6，不支持 systemd；rootless overlay 必须删除 unit 和 Quadlet。s6、s6-rc、
  `newuidmap` 与 `newgidmap` 都是宿主接口，不进入 derivation 依赖，也不在 bundle 内增加
  wrapper。
- 默认 rootless 网络是 pasta，`conf/networks` 初始为空并持久化。不要继承 rootful bridge，
  也不要增加 fuse-overlayfs fallback。
- wrapper 只覆盖 rootful 与 rootless 的真实差异。共享策略应回到 `packages/podman/conf`，
  避免维护第二份配置。

## Validation

install check 必须证明 overlay 的公共 payload 与 rootful base 一致，并覆盖 bundle 搬迁、
s6 模板渲染、宿主 ID-map helper 检查、per-user socket、持久与易失路径，以及不含 systemd
文件。真实验收需在配置了 subuid/subgid、unprivileged user namespace 与 cgroup v2 的 Linux
环境运行 pull/run、pasta DNS/出网、端口发布、service restart 和 host reboot。
