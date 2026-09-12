# bm Usage

`bm` 从 `ghcr.io/curoky/standalone-binaries` 安装和管理可搬运的 standalone
packages。支持的平台：

- `linux-x86_64`
- `linux-arm64`
- `darwin-arm64`

## Install

首次安装需要 `curl` 和 `tar`：

```bash
curl -fsSL https://raw.githubusercontent.com/curoky/standalone-binaries/master/cmd/binman/install.sh | bash
```

默认把 `bm` 安装到 `~/.local/bin/bm`。可通过 flag 或环境变量修改：

```bash
curl -fsSL https://raw.githubusercontent.com/curoky/standalone-binaries/master/cmd/binman/install.sh |
  bash -s -- --prefix /usr/local/bin

curl -fsSL https://raw.githubusercontent.com/curoky/standalone-binaries/master/cmd/binman/install.sh |
  BINMAN_INSTALL_DIR=/usr/local/bin bash
```

也可以在 bootstrap 后直接下载 package 到当前目录，不创建安装状态：

```bash
curl -fsSL https://raw.githubusercontent.com/curoky/standalone-binaries/master/cmd/binman/install.sh |
  bash -s -- ripgrep fd
```

`install.sh` 的 `--prefix` 是 `bm` 可执行文件的安装目录；`bm --prefix` 则是 package
store、profile 和聚合链接的根目录，两者含义不同。

## Global Options

```text
--prefix DIR   package 安装根目录
--arch ARCH    覆盖自动检测的平台
--verbose      同时把详细日志输出到 stderr
```

当 `bm` 已由自身管理时，`--prefix` 默认从
`<prefix>/store/binman/bm` 推导；bootstrap binary 不在该布局中时默认使用
`/opt/bm`。普通用户通常应显式设置可写目录，例如：

```bash
bm --prefix "$HOME/.local" install ripgrep
```

涉及安装状态的命令会把详细日志追加到 `<prefix>/binman.log`。

## Package Commands

搜索和查看当前平台可用的 packages：

```bash
bm search rip
bm list --all
```

安装 package。默认在 store 中保存 package，并在 prefix 下创建相对 symlink：

```bash
bm --prefix "$HOME/.local" install ripgrep fd
bm install --link=false python314
bm install --force ripgrep
```

查看、列出和删除已安装 package：

```bash
bm info ripgrep
bm list
bm remove ripgrep
```

检查和升级：

```bash
bm outdated
bm upgrade
bm upgrade ripgrep fd
```

`upgrade` 不带参数时升级全部已安装 packages，并保留各 package 原有的 link 状态和
architecture。显式传入 `--arch` 可覆盖升级目标的平台。

只下载并解压，不写入 store 或安装状态：

```bash
bm download ripgrep fd
bm download --output ./tools ripgrep
```

每个 package 会解压为输出目录下的同名目录，例如 `./tools/ripgrep/`。

查看 `bm` 的构建信息：

```bash
bm version
```

所有命令和选项可通过 `bm --help` 或 `bm <command> --help` 查看。

## Manifest

`bm sync` 使用 YAML manifest 声明完整环境，默认读取当前目录的 `binman.yaml`：

```yaml
prefix: /opt/bm
arch: linux-x86_64
packages:
  link:
    - ripgrep
    - fd
  unlink:
    - python314
profiles:
  go:
    - gopls
    - delve
```

- `packages.link` 安装 package，并把内容链接到 prefix。
- `packages.unlink` 只安装到 store，不链接到 prefix。
- `profiles.<name>` 安装 package，并链接到 `<prefix>/profile/<name>/`。
- `prefix` 和 `arch` 可省略；命令行显式传入的值优先于 manifest。
- 同一 package 可出现在多个位置，最终只安装一次；`packages.link` 优先。
- YAML 只允许一个 document，未知字段会报错。

同步默认 manifest 或指定文件：

```bash
bm sync
bm sync ./toolchain.yaml
bm sync --force
bm sync --prune
```

`--prune` 会删除当前 prefix 中未被 manifest 引用的 packages。Profile tree 在每次
sync 时按 manifest 完整重建。

## Layout

给定 `--prefix <prefix>`，主要路径如下：

```text
<prefix>/
├── store/<package>/       package 内容与 .binman-meta
├── profile/<name>/        profile 聚合链接
├── binman.log             操作日志
└── ...                    packages.link 创建的聚合链接
```

Package 之间相互独立，`bm` 不解析或自动安装运行时依赖。多个 packages 提供同一路径
时，后安装或 manifest 中靠后的 package 覆盖该聚合链接。
