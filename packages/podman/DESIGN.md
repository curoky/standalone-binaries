# Rootful Podman 部署设计

## 安装过程

将 bundle 解压到最终目录后，以 root 原地执行 `bin/install.sh`。脚本把模板渲染为
`/etc/systemd/system/podmanxd.service`，复制 `podmanxd.socket`，执行 `systemctl daemon-reload`，
然后启用并启动 socket。它不会复制程序、初始化 storage、探测网络或创建持久数据。
上游 tmpfiles 配置不会进入 bundle；`/run/podman` 完全由 unit 的 `RuntimeDirectory` 管理。

socket activation 在第一次连接 `/run/podman/podman.sock` 时启动 `bin/podman-server`。
`bin/podman` 与 `bin/docker` 是 remote client，始终连接这个 socket；`_podman` 只供 bundle
内部调用。Podman 5 与 6 使用相同 unit 和 socket 名，宿主只能激活其中一版。

## 文件与状态

设解压目录为 `$root`：

| 内容 | 路径 | 生命周期 |
| --- | --- | --- |
| 程序与 helper | `$root/bin`、`$root/libexec/podman` | 随 bundle |
| 固定配置与 CA | `$root/conf` | 随 bundle |
| image、container、volume 与数据库 | `$root/data/graphroot` | 持久 |
| engine HOME 与 registry auth | `$root/data/home`、`$root/data/auth.json` | 持久 |
| network definitions | `$root/conf/networks` | 持久且可写 |
| storage runroot | `/run/podman/storage` | 易失 |
| libpod tmpdir | `/run/podman/libpod` | 易失 |
| image 临时文件 | `/run/podman/tmp` | 易失 |
| API socket | `/run/podman/podman.sock` | 易失 |

systemd 用 `RuntimeDirectory=podman` 创建 `/run/podman`。service 重启时目录可保留，宿主
重启后 `/run` 被清空并重新创建；持久容器状态仍在 bundle 内。备份或搬迁只需保留 bundle，
不要复制 `/run/podman`。搬迁后重新运行 installer，使 unit 指向新路径。已有 libpod 数据库
记录核心路径，因此不要在同一数据目录上随意改变 bundle 或 runtime 布局。

## 配置解析

`containers.conf` 保存固定 backend、network、logging、compression 与 helper 策略；
`storage.conf` 用 `PODMAN_DATA_DIR` 和 `PODMAN_RUNTIME_DIR` 分别展开 graphroot 与 runroot。
server wrapper 计算 bundle 的绝对路径并设置这两个变量，同时固定 containers、storage、
registry、signature policy、CA 与 auth 文件。会影响上述选择的外部 override 被清除。
remote client 固定 API socket，以及 Podman 启动阶段必须解析的 containers/storage 文件；
registry、policy、TLS、auth、helper 和数据路径只在 server 设置。

`network-config-dir` 和 `tmpdir` 需要运行时绝对路径，`default-mounts-file` 没有 TOML 字段，
因此由 server CLI 传入。service timeout、日志级别和 helper 目录已由配置表达，不在 CLI
重复设置。Podman 的 `$BINDIR` 解析把通用 helper 固定到 sibling `libexec/podman`；conmon、
crun 与 runc 通过 bundle-only PATH 解析。

## 网络模式

rootful engine 使用 Netavark 和 nftables。bundle 预置
`conf/networks/podman.json`，定义名为 `podman` 的双栈 bridge：IPv4 网段为
`10.89.0.0/24`，IPv6 网段为 `fd4e:9a7c:5b2e::/64`，并启用 DNS。该文件既是首次
启动时的默认网络定义，也是运行期由 Podman 管理的持久配置；它随 bundle 备份和迁移，
不会写入宿主 `/etc/containers/networks`。

container 的默认 network namespace 通过这个 bridge 接入宿主。Netavark 使用 bundle 内的
`aardvark-dns` 提供容器名解析，使用 bundle 内的 `nft` 配置 NAT 和端口转发。host、none、
container namespace 等显式 `--network` 模式仍按 Podman 原生语义处理。宿主负责允许
network namespace、bridge 和 nftables 操作，并处理 forwarding、IPv6 NAT、uplink RA 与
预置网段冲突；bundle 不修改 sysctl。

## Source patches

源码 patch 只保留配置、环境变量或 CLI 无法产生相同运行状态的部分：

- `packaged-init.patch`，Podman 5 和 6：`--init` 只从 bundle 的 helper
  directory 查找 `catatonit`，跳过宿主
  `/usr/libexec/podman/catatonit`，并禁止 PATH fallback。
  `helper_binaries_dir` 本身不能阻止上游先命中宿主绝对路径。
- `builtin-seccomp.patch`，Podman 5 和 6：`seccomp_profile` 为空时直接
  选择编译进当前 Podman 的默认 profile，不探测宿主
  `/etc/containers/seccomp.json`。配置只能指定另一个文件，不能表达
  “使用内置 profile 且禁止宿主 fallback”。
- `registries-conf-dir.patch`，Podman 5：接受 wrapper 设置的
  `CONTAINERS_REGISTRIES_CONF`；显式主配置会结束路径选择，不再查找宿主
  或用户配置。该版本没有可提供相同行为的原生环境变量入口。
- `policy-json-env.patch`，Podman 5：回移 Podman 6 的
  `CONTAINERS_POLICY_JSON` 行为，并阻止 libpod 用不可移植的默认路径覆盖
  它。signature policy 对应字段不从 `containers.conf` 读取，因此只能通过
  该环境入口绑定 bundle 文件。
- `registries-conf-dir-v6.patch`，Podman 6：使用原生
  `CONTAINERS_REGISTRIES_CONF` 指定 bundle 主配置时同步禁止 drop-in，避免
  继续合并宿主目录。环境变量只能选择主文件，不能单独关闭 drop-in。

rootless 产物直接继承对应版本的这些 patch，没有额外源码 patch。helper、conmon、OCI runtime、
service timeout 和日志级别都由共享配置或 wrapper 环境完整表达，因此不修改对应源码。

## 可移植性与宿主接口

bundle 内常规 ELF 为 musl 静态文件，程序、helper、BusyBox、CA 和策略文件随目录
搬迁。Podman 及安装脚本在 PATH 设置完成后使用 bundle 内 BusyBox 提供的 `sh`、
`readlink`、`mkdir`、`sed` 与 `cp`；wrapper 启动和 installer 前半段仍需要宿主
POSIX shell 与 `readlink`，installer 还需要 `sed`、`printf`、`command` 和
`systemctl`。运行依赖 Linux kernel 提供 namespaces、cgroup v2、native overlay、
seccomp 与 nftables，以及本地可写 filesystem。宿主使用 systemd 管理 service。

GPU 只读取 `/etc/cdi`，宿主负责驱动、设备权限和 CDI spec。AppArmor 与 SELinux labeling
关闭，seccomp 使用编译进 Podman 的默认 profile。rootful socket 当前为 root:root、0666，
拥有该 socket 的客户端等价于获得 rootful container engine 控制权。
