---
name: github-actions-arm-debug
description: 在 GitHub Actions 临时 ARM runner 上通过受 SSH key 限制的 Upterm 会话复现、诊断或回归测试本仓库问题。用户要求使用远程 Linux ARM64 或 macOS ARM64 环境、启动 ARM 测试机、通过 SSH 调试 GitHub Actions、复现仅在 ARM 上出现的问题，或本地缺少 ARM 环境时使用。
---

# GitHub Actions ARM Debug

使用 `.github/workflows/debug-arm.yaml` 启动短生命周期 ARM runner，通过
`scripts/connect.sh` 确定性地发现 workflow run、下载连接信息并建立 SSH 会话。

## 前置检查

1. 确认 `gh auth status` 成功，当前用户对仓库有 workflow 权限。
2. 确认 workflow 已存在于默认分支。`workflow_dispatch` 不能只存在于未合并分支。
3. 使用专用 SSH private key；脚本只把对应 public key 作为本次 workflow input 传给 runner。
4. 确认待测代码已经存在于远程 ref。runner 无法看到本地未提交修改；未经用户授权不要自行 commit 或 push。

私钥默认路径是 `/workspace/.secrets/github-actions-debug`。不得把 private key 放入仓库、
workflow input 或 GitHub Actions secret。public key 不是 secret；runner 的 Upterm session
只接受该 key。

## 启动并连接

从仓库根目录执行：

```bash
.trae/skills/github-actions-arm-debug/scripts/connect.sh \
  --runner ubuntu-24.04-arm \
  --ref <remote-ref> \
  --key /workspace/.secrets/github-actions-debug
```

macOS ARM64 使用 `--runner macos-26`。脚本会：

1. 从 private key 派生本次 session 使用的 public key。
2. 生成唯一 session，携带 public key 触发 `debug-arm.yaml`。
3. 等待对应 run 和 `upterm-<session>` artifact。
4. 使用 `IdentitiesOnly=yes` 建立交互式 SSH 会话。

workflow 会 fail-closed 校验实际架构：Linux 必须是 `aarch64`，macOS 必须是 `arm64`，
避免 runner label 漂移后在错误架构上产生误导性的结果。

首次使用或排查参数时先执行无副作用检查：

```bash
.trae/skills/github-actions-arm-debug/scripts/connect.sh \
  --runner ubuntu-24.04-arm \
  --ref <remote-ref> \
  --key /workspace/.secrets/github-actions-debug \
  --dry-run
```

## 远端执行

连接后先确认实际架构和 checkout：

```bash
uname -a
uname -m
git status --short
git rev-parse HEAD
```

遵循根 `AGENTS.md` 的验证顺序，先运行最小目标。例如：

```bash
nix build .#<name>
nix build .#tarballs.<system>.<name>
```

Linux 用 `file`、`ldd` 检查 musl 全静态产物；macOS 用 `file`、`otool -L` 检查每个
Mach-O 仅依赖 `/usr/lib`、`/System/Library/Frameworks` 或包内相对 dylib，并用
`codesign --verify --strict` 验证 artifact 归一化后的签名。

记录完整命令、exit code 和关键输出。不得把 eval、dry-run 或静态审查报告成实际构建通过。

完成后必须在远端执行：

```bash
touch "$GITHUB_WORKSPACE/continue"
exit
```

如果连接丢失，使用 `gh run cancel <run-id>` 回收 runner。

## 收尾

- 报告 runner、ref、commit SHA、run URL、执行过的命令以及通过/失败结果。
- 把已确认的复现或回归命令固化为普通自动化测试；不要把 SSH 会话当作长期测试方案。
- 不给 debug job 添加发布权限、生产 secret 或 `pull_request_target` 触发器。
- 未经用户要求，不发布包、不改 registry、不删除远程分支。
