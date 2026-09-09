# Nixcache Agent Guide

`cmd/nixcache/` 是本仓库专用的 GHCR-backed Nix binary cache，提供 `push`、
`serve`、`probe`、`prune` 和 `size`。全局约束见根 [`AGENTS.md`](../../AGENTS.md)，CI
触发与发布流程见 [`docs/release-model.md`](../../docs/release-model.md)。

## 设计

- Nix 通过 `nix copy --to file://...` 生成 closure、NAR 和 narinfo；Go 负责校验、
  OCI 编排和 HTTP serving。
- Cache repository、listen address、refresh interval 和 media type 固定在代码中。
- Segment immutable；每次 push 发布独立 tag，matrix job 可并发执行。
- Snapshot 是原始 `flake.lock` 的 SHA-256。每个 snapshot segment 引用完整 closure，
  NAR blob 由 registry 按 digest 去重。
- `packageKey` 是稳定 package identity；`runId` 只用于诊断。
- 二进制以 `CGO_ENABLED=0` 构建。`push` 依赖宿主 `nix`，其他命令不调用外部程序。

## 核心概念

- **snapshot**：原始 `flake.lock` 的 SHA-256，记录一整套锁定的 nixpkgs channel
  版本，用于上传归属和 retention 分组，不是 cache 读取边界。同平台不同 snapshot
  的 segment 可以按确切 store path 复用；lock 改变不应让未改变的 store path 不可见。
- **segment**：一次 `push` 产出的不可变单元，一个 OCI image manifest，包含某个包在
  某 snapshot、某 system 下的完整 closure（metadata layer 加若干 NAR layer）。同一包
  重跑只新增 segment，不覆盖旧的。
- **packageKey**：稳定的包身份，值为 matrix package 名，由 `push --key` 或
  `NIXCACHE_PACKAGE_KEY` 传入。它是 retention 去重键；`runId` 不参与 identity。

segment tag 编码了前两者：

```text
v1-<snapshot前16位>-<system>-<runId>-<random>
└──────── snapshot 与 system ──────────┘└── 每次 push 唯一 ──┘
```

`serve` 按 tag 中的 system 筛选所有现存 snapshot，再校验 metadata 的 system 一致；
它只依赖宿主平台，不读取 checkout 的 `flake.lock`。`runId`+`random` 保证并发 matrix
job 的 tag 不相撞；tag 发布后不可修改，否则进程内已缓存的 metadata 不会重新读取。

## OCI Schema

Cache repository：

```text
ghcr.io/curoky/standalone-binaries-cache
```

Segment tag：

```text
v1-<snapshot-prefix>-<system>-<run-id>-<random-id>
```

每个 segment 是 OCI image manifest：第一层是
`application/vnd.curoky.nixcache.segment.v1+json` metadata，其余层是
`application/vnd.curoky.nixcache.nar.v1` NAR blob。每个 NAR descriptor 的
`org.nixos.store.hash` annotation 对应一个 metadata entry。

读取 segment 时 fail-closed 校验 tag、metadata、store hash、narinfo、NAR URL、
digest、size、media type 和 annotation 一致。

## Commands

`push --key <package-key> <store-path>...` 创建临时 file cache，有限并发上传 NAR，最后
发布 metadata 和按 store hash 排序的 layer。`--key` 或
`NIXCACHE_PACKAGE_KEY` 必填；`NIX_SIGNING_KEY_FILE` 传给 Nix。

`serve` 监听 `127.0.0.1:37515`，首次并发加载同平台所有现存 segment 的 manifest 和
metadata，不预下载 NAR payload。每 5 分钟重新列举 tag，仅读取新增 segment，并从内存
移除已消失的 tag；未变化的不可变 segment 不重复请求 manifest 或 metadata。

每次成功刷新按 `CreatedAt`、tag 升序合并 entries，同一 store hash 选择最新记录，再
原子替换 narinfo 和 NAR index。删除最新记录后，仍存在的旧 segment 可继续提供该 path。
日志记录 snapshot 数、复用/加载/移除 segment 数和耗时。

首次加载完成前 `/nix-cache-info` 返回 `503`。Repository 不存在视为空 cache；首次加载
错误终止服务，周期刷新错误保留完整的上一份 index 和 segment 缓存，不提交部分结果。
列举后读取时消失的 segment 跳过，不记入缓存，后续重新出现时会再次读取。`serve` 只读，
不删除任何远端 segment。

`probe <store-path>` 查询本地 `serve` 的确切 narinfo，并验证其中的 `StorePath`。退出码
`0` 表示命中，`1` 表示明确的 `404` miss，`2` 表示连接、HTTP 或 narinfo 协议错误。CI
只能把 `1` 当作待构建；其他非零状态必须终止 discovery。

Cache 自身不签名；从其他 cache 复制的 narinfo 可能保留原签名，本仓库构建的 path
通常没有签名。CI 必须把固定的 loopback store URL 配置为 `trusted=true`，不得用全局
`require-sigs=false` 放宽其他 substituter：

```text
http://127.0.0.1:37515?trusted=true
```

清理（retention）只由 `prune` 执行，按 system 独立计算：

1. 按最新 segment 时间保留最近 `N` 个 snapshot，默认 `N=2`（`--snapshot-keep`）。
2. 每个保留 snapshot 内按 `packageKey` 分组：保留组内最新 segment 起
   `--package-retain-days`（默认 2）天滚动窗口内的所有 segment；窗口内不足
   `--package-keep`（默认 2）个时，按 `CreatedAt` 降序补到该数。择新以
   `CreatedAt` 为主键，相等时用 tag 字符串做确定性 tie-break。
3. 保留 snapshot 内空 `packageKey` 的 segment 全部保留（无法安全归属）。
4. 删除其余 segment。

- `prune` 必须先解析全部目标 version ID，再进行任何删除；`--dry-run` 不发请求。
- `size` 只统计 metadata 和 NAR layer payload，并按 digest 去重。

## Binary Distribution

`.github/workflows/build-nixcache.yaml` 发布 `nixcache-linux-x86_64`、
`nixcache-linux-arm64` 和 `nixcache-darwin-arm64`。Artifact 只有一个 tar.gz
layer，归档布局为 `nixcache/nixcache`；`install.sh` 只依赖 `curl` 和 `tar`。

- 修改 repository、tag、media type、segment metadata、retention identity 或归档布局时，
  同步 workflow、installer 和 `docs/release-model.md`。
- 保持 repository-specific 实现，不为假设中的 registry 或 cache backend 预造抽象。

## 验证

```bash
CGO_ENABLED=0 go test ./cmd/nixcache
CGO_ENABLED=0 go vet ./cmd/nixcache
CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build ./cmd/nixcache
CGO_ENABLED=0 GOOS=darwin GOARCH=arm64 go build ./cmd/nixcache
bash -n cmd/nixcache/install.sh
shellcheck cmd/nixcache/install.sh
```

真实 Nix round-trip：

```bash
NIXCACHE_TEST_STORE_PATH=/nix/store/<path> \
  CGO_ENABLED=0 go test -run '^TestNixRoundTrip$' -v ./cmd/nixcache
```
