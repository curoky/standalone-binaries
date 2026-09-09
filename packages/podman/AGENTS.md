# Podman 包设计

本目录把 Podman 拆成两个并行版本，共享同一套 bin/conf/patch 资源，但每个版本用
一个完全自包含的 derivation 文件，不抽象公共 nix 逻辑：

- [`podman5.nix`](podman5.nix)：跟随上游 nixpkgs pin 的 podman 5.x（当前
  5.8.4），不 override `version`/`src`/`vendorHash`，复用 nixpkgs 拉取的源码与
  module 集。
- [`podman6.nix`](podman6.nix)：把 podman 6.x pin 到具体 release（当前 6.1.0），
  自行 override `version`/`src` 并把 `vendorHash` 设为 `null`（6.1.0 源码自带
  committed vendor/）。

两个 `.nix` 文件的 `runcStatic`、`podman.override`、patch、`postInstall` 与
`installCheckPhase` 目前内容一致，但刻意各自完整维护，改动其一时需手动同步另一个。

两个版本各自将 Podman 发布为可整体移动的目录。所有运行时依赖都应尽可能打包到
`libexec/podman`，而不是从宿主系统获取。以下运行时查找契约与打包约定对两者同时
适用。

## 运行时查找契约

运行中的 `_podman` 根据自身位置确定 `BINDIR`，并且只从以下目录解析随包提供的
二进制：

```text
$BINDIR/../libexec/podman
```

该规则覆盖 OCI runtime、`conmon`、`conmonrs`、容器 init、网络 helper、Quadlet，
以及所有通过 Podman helper 查找 API 解析的二进制。

- 整体移动包目录后，查找行为必须保持不变。
- 用户配置、`CONTAINERS_HELPER_BINARY_DIR`、系统目录和 `PATH` 都不得改变随包
  二进制的查找位置。
- 随包二进制缺失时，要求它的调用点必须报错；Podman 不得回退到宿主系统中的同名
  二进制。
- 未设置 link-time helper 目录的非本包构建仍应保持上游查找行为。

`strict-helper-search.patch` 在共享 resolver 边界实现该契约。包级 patch 不得重新引入
系统路径列表。v5.8.x 与 v6.1.0 的 vendor 路径都已是 `go.podman.io/common`，两个版本
复用同一份 patch。

`policy.json` 的定位只用 `bin/podman`/`bin/podman-server` 设置的
`CONTAINERS_POLICY_JSON=$root/../conf/policy.json`。podman 6.x 上游已原生读取该 env，
podman 5.x 未支持，故 `podman5.nix` 额外应用 `policy-json-env.patch`，给
`vendor/go.podman.io/image/v5/signature/policy_config.go` 的 `defaultPolicyPathWithHomeDir`
backport 同样的 env 覆盖（优先级低于 `sys.SignaturePolicyPath`、高于用户与系统默认路径，
值原样使用、缺失即报原始 ENOENT 而不回退）。`podman6.nix` 不需要该 patch。

## 打包约定

两个 `.nix` 文件都将上游 helper bundle 复制到 `libexec/podman`，并把字面量
`$BINDIR/../libexec/podman` 作为查找模板链接进 Podman。新增运行时依赖时，应尽可能
把它加入该 bundle，并复用已有共享 resolver，不要增加面向宿主系统的包级查找逻辑。

helper bundle 里的 `aardvark-dns` 由两个 `.nix` 文件通过
`podman.override { aardvark-dns = ...; }` 换成本地 patch 版
（[`packages/aardvark-dns/`](../aardvark-dns/)）。上游 aardvark-dns 2.1.0 在
`src/main.rs` 无条件调用 `libc::close_range`，musl 的 libc 绑定只导出
`SYS_close_range` 常量而没有该 wrapper 函数，musl-static 构建会失败；patch 改用
`libc::syscall(libc::SYS_close_range, ...)`，仅动 crate 自身源码、不动 vendor，故不
需要 cargoHash override。改动其一时需同步另一个。

`bin/podman` 和 `bin/podman-server` 必须根据自身位置设置配置文件路径、
`PODMAN_DATA_DIR` 及 `data/tmpdir` 下的 `TMPDIR`。`storage.conf` 通过
`PODMAN_DATA_DIR` 把 `graphroot` 和 `runroot` 定位到 sibling `data` 目录；
配置文件不得写死安装前缀。

`bin/install.sh` 原地安装当前包目录，不得复制或移动 `bin`、`conf`、`libexec` 和
`data`。它只创建 sibling `data`，并从 `conf/podmanxd.service` 模板渲染当前包根目录
的真实路径后注册 systemd unit。

## IPv6 / dual-stack 网络

默认网络在运行时自适应选择，保证在任意宿主机（dual-stack / IPv4-only /
IPv6-disabled）上都能起：`bin/podman-server` 启动时读
`/proc/sys/net/ipv6/conf/all/disable_ipv6`，为 `0` 时把 `conf/networks/podman.json`
软链到 dual-stack 候选 `conf/networks.d/dualstack.json`（IPv4 `10.89.0.0/24` +
IPv6 ULA `fd4e:9a7c:5b2e::/64`），否则软链到纯 IPv4 候选
`conf/networks.d/ipv4.json`（避免在禁用 IPv6 的机器上 netavark 配 IPv6 bridge 失败、
连带 `podman run` 整体报错）。网络后端固定 netavark，容器 DNS 由 bundle 的
aardvark-dns 提供。

`containers.conf` 只声明 `network_backend = "netavark"`，**不写死 `default_network`**
——两份候选内网络名都叫 `podman`，即 podman 的内建默认网络名，故无需 override，也无需
写 `default_network`。`network_config_dir` **不做环境变量展开**（不同于
`storage.conf` 的 `graphroot`/`runroot` 由 containers/storage 主动 `os.ExpandEnv`），
故扫描目录 `conf/networks` 由 `podman-server` 按自身位置解析真实路径，经
`--network-config-dir` 注入。

网络定义用「扫描目录 + 候选目录」两级布局：

- `conf/networks/` 是 netavark 实际扫描的目录，随包预建（内含 `.gitkeep` 占位），
  运行时只放一个软链接 `podman.json`。netavark 强制要求文件名与其内网络名一致，
  否则告警跳过；软链接名 `podman.json` 正好匹配内网络名 `podman`。
- `conf/networks.d/` 是两份候选定义 `dualstack.json`、`ipv4.json`，**不被扫描**
  （避免文件名 `dualstack.json` 与内网络名 `podman` 不符触发告警跳过）。

使用场景是原地执行且包目录可写，故软链接直接建在 `conf/networks` 下、指向同包的
`conf/networks.d/`（相对软链，不含安装绝对路径）。`bin/podman` 是 `--remote` 客户端，
网络配置由 server 端决定，不接受 `--network-config-dir`，无需改动。

静态 JSON 有两个必须遵守的约束（实测得出）：

- 必须带合法 `id`（64 位 hex）。省略 `id` 会被 netavark 判为 `invalid network ID`
  并跳过整份网络定义。当前 `id` 取 `sha256(<候选名>)`，稳定可复现。
- `created` 可省略，podman 读取时补零值 `0001-01-01T00:00:00Z`；未写的运行期字段也会
  自动补齐。两份候选同一时刻只有一份经软链接生效，故共用 `network_interface`
  `podman0` 不会冲突。

网段不绑定具体宿主机；仅当宿主机已占用该 IPv4 网段或该具体 ULA `/64`（概率极低）时才
需改网段。IPv6 **转发**只影响容器出网、不影响建网，故不单独建网络，仍由用户按需开启
（见下），`podman-server` 不修改宿主内核。

维护提示：netavark 磁盘 schema 随版本演进。每次 bump podman5/podman6 时须重新核对两组
JSON 能被新版本正确加载（`_podman --network-config-dir=<dir> --network-backend=netavark
network inspect <name>`，非 root 需先处理 store 初始化），schema 漂移只在运行时暴露、
build 期发现不了。此约束已记入回归清单。

宿主 IPv6 转发不由本包设置（install.sh 不碰宿主内核参数）。要让容器 IPv6 出网/
互通，用户须手动开启转发：

```bash
sudo sysctl -w net.ipv6.conf.all.forwarding=1
# 持久化
echo 'net.ipv6.conf.all.forwarding = 1' | sudo tee /etc/sysctl.d/99-podman-ipv6.conf
sudo sysctl --system
```

若上联网卡靠 RA/SLAAC 取址，开转发后还需 `net.ipv6.conf.<uplink>.accept_ra=2`。
ULA 地址出公网需要 NAT66，宿主内核须支持 `ip6table_nat`（netavark 6.x 用
nftables，主流内核已内置）。

`installCheckPhase` 应聚焦 resolver 行为，验证 relocation、sibling 目录查找成功，以及
无法逃逸到外部二进制。至少覆盖 conmon 专用 resolver、OCI runtime resolver 和通用
helper resolver。检查应直接调用 resolver，不得通过启动完整 Podman runtime 间接触发；
build sandbox 的 kernel、namespace、storage 或 cgroup 状态不属于该契约。
