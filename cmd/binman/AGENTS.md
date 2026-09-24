# Binman Agent Guide

`cmd/binman/` 实现 OCI package installer `bm`。用户说明见 [`USAGE.md`](USAGE.md)，
全局 artifact 约束见根 [`AGENTS.md`](../../AGENTS.md)。

## 产品边界

- Registry 固定为 `ghcr.io/curoky/standalone-binaries`，只使用 anonymous pull。
- 仅提供 `install` 和 `remove`；重新 install 即 upgrade。
- 支持的平台只有 `linux-x86_64`、`linux-arm64` 和 `darwin-arm64`，由运行平台自动选择。
- package 相互独立，不解析依赖、版本约束或 Nix cache。
- YAML 是批量安装计划，不是完整 desired state；删除 YAML 条目不会卸载 package。

## OCI Artifact

Package tag 是 `<package>-<architecture>`。Manifest 必须恰好包含一个
`application/vnd.oci.image.layer.v1.tar+gzip` layer，archive 必须以 package 名为唯一
顶层目录。Client 使用 layer digest 判断已安装内容是否需要重新下载。

一次 install 只创建一个共享 `remote.Puller`，通常只触发一次 token exchange。Manifest
resolve 并发为 4，blob download 并发为 16，解压并发为
`runtime.GOMAXPROCS(0)`。所有下载和解压成功后，store replacement 与 link 按声明顺序串行
执行。

## Layout 与状态

```text
<prefix>/
├── store/
│   ├── .lock
│   └── <package>/.binman-meta
├── bin/
└── <其他 link-to 目录>/
```

`.binman-meta` 只记录 layer digest 和 link targets。它用于跳过未变化的 blob，并在 package
升级、改变 link target 或 remove 时清理旧链接。它是 client 保留的唯一本地状态。

`link-to` 是相对 prefix 的目录：`.` 表示 prefix，自定义值如 `profile/go`。省略表示只安装
到 store。同一 package 可以有多个 target；同一 target 中的文件冲突由后执行的 link
覆盖。所有链接都使用相对 symlink，因此 prefix 可整体移动。

修改 prefix 的阶段持有 `<prefix>/store/.lock` 文件锁；网络与解压阶段不持锁。同一批次
不会在下载或解压失败后修改 prefix，但串行 commit 不提供整批回滚，失败后重新执行相同命令
必须能够调和状态。

## YAML

```yaml
prefix: /opt/bm
installs:
  - packages: [ripgrep, fd]
    link-to: .
  - packages: [gopls, delve]
    link-to: profile/go
  - packages: [python314]
```

Schema 使用 strict single-document decoding。未知字段、空 group、非法 package 名和越过
prefix 的 link target 必须报错。CLI packages 追加在 YAML groups 后，因此其 link 冲突
优先级更高。相同 package 只 resolve/download 一次，link target 去重后全部应用。

## 安全边界

- Tar path、symlink target 和 hardlink target 必须留在 staged package 内。
- Archive 顶层必须准确匹配 package 名，拒绝特殊 entry type 和 archive 自带的
  `.binman-meta`。
- Package 不得向 prefix 根目录暴露 `store` 路径；`link-to` 也不得指向 `store`。
- Link parent 可以使用 prefix 内部 symlink，但不能沿 symlink 写出 prefix。
- Link 可以覆盖另一个 package 创建的 symlink，但不得覆盖普通文件或真实目录。
- Unlink 只删除仍然指向目标 package store 的 symlink。
- Stage 必须位于 `store` 内，确保 store replacement 不跨 filesystem。

## 实现边界

- `main.go`：Cobra command、平台检测和默认 prefix。
- `manifest.go`：strict YAML、install plan 和 link target 校验。
- `registry.go`：共享 Puller、manifest resolve 和 blob 下载。
- `install.go`：分阶段并发、串行 commit 和 remove。
- `store.go`：metadata、文件锁、基于 Go `os.Root` 的安全解压、store replacement 与 link。

不要重新引入 profile、search/list、outdated、独立 download、archive cache、依赖解析或兼容
旧布局的迁移逻辑。

## 验证

```bash
CGO_ENABLED=0 go test ./cmd/binman
CGO_ENABLED=1 go test -race ./cmd/binman
CGO_ENABLED=0 go vet ./cmd/binman
CGO_ENABLED=0 go build ./cmd/binman
bash -n cmd/binman/install.sh
shellcheck cmd/binman/install.sh
```
