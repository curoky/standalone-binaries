# bm Usage

`bm` 从 `ghcr.io/curoky/standalone-binaries` 安装 standalone packages。支持
`linux-x86_64`、`linux-arm64` 和 `darwin-arm64`，平台自动检测。

## Bootstrap

首次安装需要 `curl` 和 `tar`：

```bash
curl -fsSL https://raw.githubusercontent.com/curoky/standalone-binaries/master/cmd/binman/install.sh | bash
```

默认安装到 `~/.local/bin/bm`。bootstrap 与 `bm` 的 `--prefix` 含义一致，都是 package
prefix：

```bash
curl -fsSL https://raw.githubusercontent.com/curoky/standalone-binaries/master/cmd/binman/install.sh |
  bash -s -- --prefix /usr/local
```

## Install

默认 package prefix 是 `~/.local`，CLI `--prefix` 可以覆盖：

```bash
bm install ripgrep fd jq
bm --prefix /opt/bm install ripgrep fd
```

默认将 package 安装到 `<prefix>/.binman/store/<package>`，并把其中的叶子文件以相对
symlink 链接到 prefix。重新执行 install 会检查远端 layer digest：内容未变化时只调和
链接，内容变化时下载并替换 store。

自定义 link target 或只安装到 store：

```bash
bm install --link-to profile/go gopls delve
bm install --no-link python314
```

`link-to` 必须是 prefix 内的相对路径。`.` 表示 prefix；绝对路径、`..` 和 `.binman`
均不允许。同一个 package 需要链接到多个 target 时使用 YAML。

## YAML

```yaml
prefix: /opt/bm

installs:
  - packages:
      - ripgrep
      - fd
    link-to: .

  - packages:
      - gopls
      - delve
    link-to: profile/go

  - packages:
      - python314
```

安装 YAML 中的 packages：

```bash
bm install --file binman.yaml
```

也可以追加 CLI packages；它们默认链接到 prefix，并在文件冲突时后执行：

```bash
bm install --file binman.yaml yq bat
```

CLI 显式 `--prefix` 优先于 YAML。相同 package 只下载一次，但会链接到所有声明的
targets。YAML 是安装计划，不会卸载从文件中删除的 package。

## Remove

```bash
bm remove ripgrep fd
```

Remove 会清理仍指向这些 packages 的 symlink，然后删除对应 store。若一个链接后来被其他
package 覆盖，不会误删它。

## Concurrency

- Manifest resolve：4
- Blob download：16
- Archive extraction：当前 Go runtime 可用 CPU 数量
- Store replacement 和 link：1，按声明顺序执行

同一批次共享一个 registry Puller，以复用认证 token 和连接。所有下载和解压成功后才开始
修改 prefix。
