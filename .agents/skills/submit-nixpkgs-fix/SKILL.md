---
name: submit-nixpkgs-fix
description: 将已定位的通用构建问题提交给 NixOS/nixpkgs，或处理已有 nixpkgs PR 的 review、验证和上游覆盖检查。用于用户明确要求 upstream 修复、提交 PR、回复 review 或判断 PR 是否可关闭时。
---

# Submit nixpkgs fixes

只提交在 nixpkgs 中独立成立的修复。本仓库的资源布局、wrapper 和产品默认值留在本仓库。
本地包维护使用 [maintain-packages](../maintain-packages/SKILL.md)。

## 1. 复现与实现

1. 阅读目标实现、定制记录及实际日志，在 GitHub 搜索已有 issue/PR 和修复。
2. 为新修复从当前 `NixOS/nixpkgs:master` 建独立 checkout；已有 PR 使用其分支。
   阅读该 checkout 的 `CONTRIBUTING.md`、`pkgs/README.md`、PR template 和目录规则。
3. 在未修改表达式上复现失败，记录 revision、package set、失败阶段和原始错误。
   静态、native 和 cross 构建须显式选择相应 package set。
4. 在上游表达式中修 root cause，优先用已有 hook、platform predicate 和依赖 splicing。
   保持版本及无关 metadata 不变；软件源码问题需要时提交软件上游 patch。

## 2. 验证

- 在相同 revision 验证修复前失败、修复后原阶段通过，并构建受影响的 native/cross 目标。
- 运行程序 smoke test；静态包检查 ELF/Mach-O、动态依赖和 closure。`file`、
  `nix-store -qR` 与 smoke test 分别证明不同事情。
- 运行 formatter、`git diff --check`、相关测试和 `nixpkgs-review`。
  有 merge base 时使用 `nixpkgs-review rev HEAD`；浅 checkout 可改用完整基线和 `wip`。
- 如实报告 cache hit、未执行的目标平台测试和无受影响 derivation 的结果。
  需要 ARM 执行环境时使用 [ARM 验证](../github-actions-arm-debug/SKILL.md)。

## 3. 准备提交与审核

按当前 nixpkgs 规则准备 commit 和 PR，通常 commit 为 `<attr>: <action>`。
不添加 `Co-authored-by`；按当前 AI policy 在 commit trailer 和 PR summary 中披露
真实的工具和模型，包括要求的 `Assisted-by`。

先完成本地 diff、验证、commit 文案和 PR/评论草稿，再处理贡献规则要求的人工审核。
若本次内容尚未获得所需审核，展示这些具体产物和验证边界，引用 checkout 中要求审核的
原文并请求确认；不要代替用户声称已审核。已有授权覆盖的内容不重复询问。

## 4. 发布或更新 PR

1. 检查 `gh auth status`、fork parent 和 push 权限。推送到用户 fork 的 feature branch。
   需要使用当前 gh 凭据时：

   ```bash
   git -c credential.helper= \
     -c 'credential.helper=!gh auth git-credential' push -u fork <branch>
   ```

2. 403 时先区分仓库权限与 token scope；不输出 token。按 GitHub 认证指引修复权限。
3. 用 `gh pr create` 或更新已有分支。正文使用结构化参数或 `--body-file`，核对远端
   base/head、commit、正文、disclosure 和 checks。
4. Review 迭代只修对应代码并回复已获授权的评论；未要求时不重写 PR 描述。
   推送和回复完成后再处理已解决的 review thread。

## 5. 上游已覆盖或合并

用户询问 PR 是否已多余时，核对修复 ancestry，并实际构建当前上游包，检查链接、closure
和运行行为后给出结论。关闭 PR 或发评论按用户授权执行。

只有本仓库锁定的 nixpkgs 已包含修复且最终 artifact 验证通过，才按
[maintain-packages](../maintain-packages/SKILL.md) 删除本地修正；PR 创建或合并本身不够。
