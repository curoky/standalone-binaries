# Rootless Podman deployment

## Installation

每份 bundle 服务一个普通用户。解压到最终目录后，以 root 执行 `bin/install.sh USER`。
程序、固定配置和 s6 模板由 root 持有，目标用户只能写 `data`、`conf/networks` 和运行态
目录，避免修改之后会由 root 执行的脚本。

Installer 查询 UID，检查宿主 `newuidmap`、`newgidmap`、`s6-setuidgid`，将模板写入
`/etc/s6/s6-rc.d/podman-<uid>` 并加入 `default` bundle。它只生成 source tree；部署方在
收集全部服务后统一执行 `s6-rc-compile`，运行中更新则执行 `s6-rc-update`。

Run script 先以 root 建目录、设置属主和权限，再用宿主 `s6-setuidgid` 降权启动
`podman-server`。Server 根据降权后的 UID 设置 `USER` / `LOGNAME`，直接监听用户
socket；`bin/podman` 按调用者 UID 连接。

## Files and state

以安装到 `/opt/podman`、用户 UID 为 `<uid>` 为例：

| 内容 | 路径 | 生命周期 |
| --- | --- | --- |
| 程序、helpers、固定配置 | `/opt/podman/bin`、`libexec/podman`、`conf` | 随 bundle |
| image、container、volume、数据库 | `/opt/podman/data/graphroot` | 持久 |
| engine HOME、registry auth | `/opt/podman/data/home`、`data/auth.json` | 持久 |
| network definitions | `/opt/podman/conf/networks` | 持久，初始为空 |
| image 临时文件 | `/opt/podman/data/tmp` | 临时、磁盘承载 |
| storage runroot | `/run/user/<uid>/podman/storage` | 易失 |
| libpod tmpdir | `/run/user/<uid>/podman/libpod` | 易失 |
| API socket | `/run/user/<uid>/podman/podman.sock` | 易失 |

服务停止时，finish script 用本地 engine 入口 `podman-server --stop-all` 停容器，不能
调用已经无法连接 socket 的 remote client。服务重启复用本次 boot 的运行目录；宿主
重启清空 `/run`，s6 重新创建运行目录，持久状态从 bundle 恢复。

备份或搬迁完整 bundle，其中 `data/tmp` 可在服务停止时清理；不要复制 `/run`。路径或 UID
改变后重装服务；不同用户不共用 bundle，以免共享数据和网络定义。镜像复制使用进程级
`TMPDIR=$PODMAN_DATA_DIR/tmp`，避免受 `/run/user` tmpfs 容量限制。

## Rootful base

Rootless derivation 复制对应 rootful bundle，删除 systemd units、Quadlet 和预置 bridge，
替换 installer、client/server wrappers 及 s6 模板。二进制、helpers、CA、registry、
signature、mount policy、`containers.conf`、`storage.conf` 与对应 rootful 输出一致。
源码 patch 直接继承，原因见 [Rootful patches](../podman/DESIGN.md#source-patches)。

Wrapper 在包内 helper PATH 之后追加标准系统 PATH，用于解析宿主安全接口；包内工具优先。

## Networking

默认 rootless 网络为 pasta，使用包内 `pasta` / `passt` 处理 DNS、出网和显式端口映射。
它不创建宿主 bridge、不修改 nftables，也不要求宿主开启 IP forwarding；显式
`--network` 模式遵循 Podman 语义。

Pasta 需要访问宿主 `/dev/net/tun`。缺失时 engine 和 pull 仍可工作，默认网络的容器
启动会因无法创建 TAP 设备失败。

`conf/networks` 初始为空。`podman network create` 生成的 Netavark definitions 保存在
这里并随 bundle 持久化；Netavark 和 pasta 在 rootless user namespace 中运行。
服务或宿主重启后网络进程和 socket 重建，容器数据与网络定义保留。

## Host interfaces

Bundle 内 ELF 为 musl 静态文件。Podman 子进程和服务脚本显式使用包内 BusyBox 的
`sh`、`readlink`、`mkdir`、`sed`、`cp`。Wrapper 和 installer 的启动需要宿主 POSIX
shell 与 `readlink`，installer 还需要宿主 `sed`、`printf`、`command`。

宿主须提供 unprivileged user namespace、cgroup v2、native rootless overlay、s6 和
s6-rc。用户的 `/etc/subuid` / `/etc/subgid` 区间不能重叠。`newuidmap` / `newgidmap`
的 setuid 或 capability 由宿主 shadow/uidmap 包管理；它们在创建 user namespace 时
运行，不复制进 bundle。

数据文件系统必须支持 unprivileged native overlay；overlay-on-overlay 通常不满足。
不自动改用 VFS 或 fuse-overlayfs。Bundle 不创建用户、不编辑 subordinate-ID 数据库、
不修改 sysctl，也不使用 systemd。

GPU 需要宿主驱动、`/etc/cdi` 和用户设备权限。Docker-compatible client 可设置
`DOCKER_HOST=unix:///run/user/<uid>/podman/podman.sock`。
