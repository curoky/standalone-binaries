---
name: github-actions-arm-debug
description: 使用 GitHub Actions 的 Upterm SSH 会话在 Linux ARM64 或 macOS ARM64 上构建和运行测试。用于 ARM 专属故障、启动 ARM 测试机、SSH 调试 Actions，或本地缺少目标 ARM 环境时。
---

# Verify on ARM

通过 [connect.sh](scripts/connect.sh) 启动
[debug-arm.yaml](../../../.github/workflows/debug-arm.yaml) 并连接短期 runner。

## 1. 准备

- 检查 `gh auth status` 和 workflow 权限，确认 workflow 已在默认分支。
- 选择存在于 origin 的待测 ref；runner 不会自动获得本地未提交改动。
  测试本地改动时可在 SSH 连接后传入 patch，记录基线和 diff；推送按已有授权处理。
- 默认私钥为 `/workspace/.secrets/github-actions-debug`；只将派生的公钥传入 workflow。
  不把私钥放进仓库、workflow input 或日志。

## 2. 启动

从仓库根目录执行，首次使用先加 `--dry-run` 检查参数与远程 ref：

```bash
.agents/skills/github-actions-arm-debug/scripts/connect.sh \
  --runner ubuntu-24.04-arm \
  --ref <remote-ref> \
  --key /workspace/.secrets/github-actions-debug
```

macOS 使用 `--runner macos-26`。脚本生成唯一 session、触发 workflow、下载连接信息，
再通过 `IdentitiesOnly=yes` 连接；Upterm 只接受本次公钥。

## 3. 验证

连接后核对环境和待测代码：

```bash
uname -m
git rev-parse HEAD
git status --short
```

Linux 必须为 `aarch64`，macOS 必须为 `arm64`。应用本地 patch 后再次核对 diff。
包构建及搬迁 smoke test 按 [maintain-packages](../maintain-packages/SKILL.md#4-验证最终输出)
执行；组件测试按对应 `AGENTS.md`。Cross-build 不能替代目标机器运行测试。

## 4. 回收与报告

保存 run URL、runner、ref、commit、额外 diff、命令和结果，然后在远端执行：

```bash
touch "$GITHUB_WORKSPACE/continue"
exit
```

连接丢失时用 `gh run cancel <run-id>` 回收 runner。报告实际执行结果及未验证项；
可重复的检查应进入普通测试。Debug job 保持最小权限，不引入发布凭据或
`pull_request_target`。
