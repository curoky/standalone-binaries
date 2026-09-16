# Podman Agent Guide

<!-- markdownlint-disable MD013 -->

## Layout

只拆两份独立 derivation：[podman5.nix](podman5.nix) 跟随锁定 nixpkgs 的 5.x，
[podman6.nix](podman6.nix) 单独选择 6.x release。bin、conf、patch 和 tests 复用；
不抽象公共 nix builder，也不抽取被入口脚本 source 的函数库。升级分别验证两版。

## Configuration ownership

| 内容 | 唯一入口 |
| --- | --- |
| runtime、network/firewall、日志、压缩、设备接口 | `conf/containers.conf` |
| storage 与 pull options | `conf/storage.conf` |
| registry、signature policy、默认 mounts | `conf/registries.conf`、`policy.json`、`mounts.conf` |
| 内部双栈 bridge | `conf/networks/podman.json` |
| 路径定位、进程环境 | `bin/podman-server` |
| systemd 安装 | `bin/install.sh` |
| remote client | `bin/podman`、同目录 `docker` 软链 |

Server 固定 crun（runc 可显式选择）、native overlay、sqlite、cgroupfs、k8s-file、
file events、netavark+nftables；rootless helper 固定 pasta。镜像推送使用 OCI +
`zstd:chunked` level 3，pull 启用 partial images；实际节省取决于 registry 的 OCI/zstd
支持与镜像内容。保留 fsync 与持久化 metadata，不启用 transient store 或跨镜像 hardlink。
容器日志上限 10 MiB，API 日志交给 systemd journal。

包携带 crun、runc、conmon、catatonit、netavark、aardvark-dns、pasta、rootlessport、
quadlet、静态 nft 和 BusyBox；只暴露使用到的 BusyBox applet。随包复制 nixpkgs CA，
seccomp 使用当前版本编译进二进制的默认 profile。没有 fuse-overlayfs 自动回退。

Server PATH 只包含 sibling `libexec/podman`，HOME、registry auth 和镜像临时文件位于
sibling `data`。libpod 运行目录沿用 rootful 上游默认 `/run/libpod`，不传 `--tmpdir`；
其 `alive` 文件随宿主重启清空，由上游刷新运行状态，不能放入持久化 data。
storage runroot 仍由 storage.conf 指向包内 data/runroot，与 libpod 运行目录分开。
XDG config/data/cache 沿用 HOME 下的上游默认目录，不单独配置或预创建；
仅显式设置 XDG runtime，因为其默认路径不在 HOME 下。主配置 env 由 wrapper 覆盖，
清除额外配置、宿主 XDG 路径和 storage env overrides。网络 backend 与 DNS 端口由
containers.conf 确定，helper env 已由 patch 忽略，不重复清理。
保留包内 CA 文件和空证书目录绑定，防止系统 CA 目录参与默认加载。netavark 的 nftables
backend 仍会尝试 firewalld 联动，通过不可连接的包内 DBus 地址关闭此可选集成。
Server 和 client 直接读取同一份 `conf/containers.conf`，没有配置模板或启动期渲染。
配置只保留有效的产品策略；helper/conmon/runtime 路径由 patch 统一限定，不重复配置。

不读取宿主默认 mounts、OCI hooks、compose provider、network plugin、AppArmor profile
或 SELinux policy。AppArmor/SELinux labeling 明确关闭，普通容器启用内置 seccomp；
显式 `--privileged` 或 `seccomp=unconfined` 遵循上游语义。不能将此行为
描述为保留了宿主 LSM 隔离。GPU CDI 只使用 `/etc/cdi`；驱动与 CDI generator 属于宿主。
默认代理不注入容器。Server 和 remote client 均绑定随包 CA；`podman login` 在客户端
本地访问 registry，同样需要此绑定。显式 `--cert-dir` 仍是用户配置能力；上游
per-registry certs.d 搜索尚未隔离，不能声称宿主所有证书配置都已封闭。

## Patch budget

| Patch | 保留理由与升级检查 |
| --- | --- |
| `strict-helper-search.patch` | 沿用上游 `$BINDIR` 展开；conmon、init、OCI runtime 汇入现有 helper resolver，只查 sibling；移除 env/PATH fallback 和 netavark 注入 `/usr/sbin`。不新增 resolver API，不复制上游 runtime 查找算法 |
| `builtin-seccomp.patch` | 默认直接使用内置 profile，删除宿主 seccomp.json 搜索；显式 profile 仍可使用。无需外置 JSON 和路径渲染 |
| `policy-json-env.patch` | 仅 5.x backport `CONTAINERS_POLICY_JSON`，并移除 libpod 向 image context 注入宿主默认 policy 路径的赋值，避免绕过 env；6.x 原生支持 |
| `registries-conf-dir.patch` | 5.x 显式 registry 主配置禁止默认 drop-ins；底层补齐环境变量入口，覆盖 remote client 传空 SystemContext 的调用 |
| `registries-conf-dir-v6.patch` | 6.x 使用现有 `DoNotLoadDropInFiles`；libimage 把 env 转成 SystemContext 显式路径，会重新启用 drop-ins，不能只测试 env 分支 |

runc 保留 upstream installPhase，只在 postInstall 还原真实静态 ELF，避免动态 wrapper。
Podman 构建依赖沿用上游，只排除 musl-static 不支持且当前配置不需要的 libsystemd；
gpgme 与 container helpers 通过 override 注入本仓库静态版本。
本地 aardvark-dns 的 musl close_range 修正仍由两版显式注入，独立登记在回归表。

helper/配置 patch 是 packaging 边界，不因 stock build 成功就能删除；上游必须提供等价
相对路径与封闭查找接口才能替换。`_podman` 是内部二进制；wrapper 才是产品入口。

## Installation and network

原地运行 `sudo ./bin/install.sh`，不复制 runtime 或搬迁 data。没有安装或启动期网卡、
firewall、GPU、storage 探测。Server 通过 `--network-config-dir` 直接读取 `conf/networks`，
不复制配置、不创建软链，也不依赖 installer 初始化网络目录。通过 API 创建或删除网络时，
配置直接写入此目录，因此该目录需可写。installer 只安装 systemd units 并启用 socket。
同一份内部双栈 bridge 同时用于双栈和 IPv6-only 宿主：

- 内部网段为 `10.89.0.0/24` + `fd4e:9a7c:5b2e::/64`，启用 aardvark DNS。
- 双栈宿主通过 IPv4 NAT 和 IPv6 NAT66 出网；IPv6-only 宿主使用 IPv6 出网，内部 IPv4
  仅提供本地通信，不会自动获得 IPv4 公网能力。
- 不提供 NAT64/DNS64；访问纯 IPv4 目标需部署环境提供转换。双栈 DNS 回答的连接
  体验取决于应用的 IPv6/Happy Eyeballs 支持。
- 宿主需要 IPv6 forwarding、IPv6 NAT 和 nftables kernel 支持；RA/SLAAC uplink
  需要正确的 `accept_ra=2`。本包不修改宿主 sysctl；网段冲突由部署方明确配置。
- 宿主 resolver 是 DNS 上游，属于网络接口。JSON name 固定 `podman`、ID 为合法稳定
  64 位 hex；active 文件必须叫 `podman.json`，否则 netavark 会跳过。

系统前提是 Linux kernel、native overlay、本地可写 filesystem 和 systemd。Podman 6
要求 cgroup v2；不降级到 v5 或其他 backend。bootstrap 仍需宿主 POSIX sh、readlink；
server 后续命令来自 bundle。installer 优先使用随包工具，并保留宿主 PATH，
直接调用宿主 systemctl，不做存在性探测。Unit 固定安装到已有的 `/etc/systemd/system`，
不提供安装目录配置。所有常规 ELF 必须 musl 全静态。
入口直接使用确定的包文件与标准 systemd 安装，不预检命令、包文件或安装路径。
路径支持空格和 `&`；部署路径约定不含 TOML/systemd 特殊字符（双引号、反斜线、
百分号、美元符号、换行）。不迁移已有容器网络或数据库，应使用匹配的新 data 目录。
libpod 数据库会记录运行目录；删除 wrapper 参数或 storage.conf 配置项不会迁移已记录的路径。

## API service and devices

`podmanxd.socket` 固定 `/run/podman/podman.sock`，root:root、0666，保留已确认的本地
普通用户可访问边界；rootful API 等价于主机高权限控制面，不扩展 TCP。
installer 执行 daemon-reload 和 enable --now socket。service 用 Type=exec、Delegate=yes、KillMode=process，
停止时调用 remote client 停止全部容器。server 不传 URI，只接收 socket activation fd。
两版共用 socket/unit 名称，不能同时安装激活。

Remote client 不创建或要求写入 server data；普通用户可在只读包目录中连接现有 socket。
整体搬迁后 helper/config/data 仍按包定位，systemd unit 需要重新运行 installer。
GPU 使用固定 `/etc/cdi`，不安装 legacy hooks；宿主生成 CDI，驱动升级后重新生成。

## Validation

两份 nix 的 installCheck 共用 `tests/`，直接使用各自 vendor 编译：

- 搬迁到带空格和 `&` 的目录后执行实际 wrapper，检查配置、storage、policy、registry 隔离；
- 幂等安装 socket、不创建 data；临时副本替换 systemd 路径并模拟 systemctl，不触碰宿主服务；
- remote client 无 server data 写入；helper 缺失且 PATH/env 有同名程序时失败；
- 真实 netavark loader 验证双栈 subnet，避免 JSON 被跳过后默默创建默认 IPv4 网络；
- libpod 默认 seccomp 路径为空，内置 profile 能生成实际 syscall 限制；server 不生成配置副本；
- 主要随包二进制的 version smoke；artifact 校验静态链接和禁止的 store 引用。

修改后构建两版 package 和 tarballs，两架构分别验证。真实集成验收需要 cgroup v2、
允许 network namespace/bridge/nftables 的 Linux，覆盖容器启动、容器间 DNS、
双栈与 IPv6-only 出网、端口发布、停止清理，以及 CDI GPU。config/helper 单测不能替代。
隔离 smoke 已覆盖 Podman 5 实际 API：隐藏 `/nix` 并提供无效宿主配置后，查询、镜像导入
和容器创建成功；移走包内 policy 后导入失败。当前 Workspace cgroup v1 不能启动 v6
service，缺少 CAP_NET_ADMIN，不能据此声称已验证容器运行和网络规则。
