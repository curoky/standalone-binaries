---
name: submit-nixpkgs-fix
description: 把 standalone-binaries 中的本地 nixpkgs workaround、override、patch、pin 或 cross/strictDeps 构建修复提炼成最小的 NixOS/nixpkgs 上游改动，完成复现、实现、验证、AI policy 人工审核、fork 推送和 PR 创建。用户要求给 nixpkgs 提交 PR、upstream packages/ 下的修复、消除本仓库本地定制，或处理 nixpkgs package expression 的 native/cross 构建问题时使用。
---

# Submit Nixpkgs Fix

把本仓库已经验证的问题转成当前 nixpkgs `master` 上可独立成立的修复。只 upstream
nixpkgs 的通用 root cause；不要把 standalone artifact packaging、产品默认值或仓库私有
约束伪装成上游 bug。

## 1. 建立证据

1. 阅读根 `AGENTS.md`、目标 `packages/<name>/`、对应 package strategy 和
   `docs/regression/` 条目。若问题属于 standalone portability，配合
   `patch-nixpkgs-standalone` skill 定位 root cause。
2. 检查本地文件头注释、Git 历史和实际失败日志；注释只能作为线索，不能代替当前复现。
3. 在 GitHub 搜索现有 nixpkgs issue/PR，避免重复提交。
4. 从 `NixOS/nixpkgs:master` 建独立 checkout，例如
   `/workspace/nixpkgs-<package>`。不要在 standalone-binaries worktree 中混入上游改动。
5. 用 stock nixpkgs 复现失败。优先构造最小 package build；需要 cross 时显式选择与问题
   一致的 `pkgsCross`/`pkgsStatic` package set。

必须保存失败阶段和原始错误。区分 eval、下载 cache、实际 build、check、install check 和
artifact validation，不能把其中一项表述成另一项。

## 2. 设计最小上游修复

- 在当前 `master` 的 package expression 上修复，不照搬本仓库 override。
- 优先使用 nixpkgs 已有 toolchain、hook、platform predicate 和 cross abstraction。
  例如 target 工具应先考虑 `stdenv.cc.targetPrefix`，不能因 native PATH 恰好可用而假设
  cross 环境存在无前缀命令。
- 只增加真正缺失的依赖；先确认 build/build、build/host 与 host/target 角色，避免用额外
  package 掩盖错误的 dependency splice。
- 保持 diff 聚焦，不顺带更新版本、重排表达式或修改无关 metadata。
- 如果问题实际属于被打包软件本身，判断应提交软件 upstream patch、在 nixpkgs 暂时携带
  patch，还是不适合提交 nixpkgs；不要强行制作 package-only workaround。

修改前搜索 nixpkgs 中的同类写法和相关类型/构建基础设施。使用 `apply_patch` 编辑，运行
仓库指定 formatter。

## 3. 按风险验证

至少完成：

1. 原始 stock 表达式在同一 revision 上失败。
2. 修复后目标构建通过，并确认原失败阶段实际执行成功。
3. native build 不回归；命中 cache 时明确写成 cache hit，不能称作本地重编译。
4. 所有受影响 cross targets 能构建。若 build platform 不能执行 target，明确说明相关
   check 被跳过，不能声称 check 通过。
5. 运行主程序 smoke test；静态包同时检查 `file`、`ldd` 或目标平台对应工具。
6. 运行 formatter、`git diff --check` 和适用的 package tests。
7. commit 后运行 `nixpkgs-review rev HEAD`。若因 native derivation 未变化而没有 impacted
   packages，如实记录。

需要 ARM 上实际执行或 NixOS 行为测试而本地没有环境时，使用
`github-actions-arm-debug` skill；不要把 cross-build 等同于目标机器运行测试。

## 4. 读取实时贡献规则

提交前从本次 checkout 完整阅读相关部分：

- `CONTRIBUTING.md`，尤其 commit、PR 和 Automation/AI policy；
- `pkgs/README.md`；
- `.github/PULL_REQUEST_TEMPLATE.md`；
- 目标目录的额外贡献说明。

不要把本 skill 中的政策摘要当作权威文本。若 nixpkgs 当前规则与这里冲突，以当前
nixpkgs 文件为准并更新本 skill。

commit 遵循 nixpkgs package convention，通常为 `<attr>: <action>`，summary 末尾不加句号。
不得添加 `Co-authored-by`。只要 LLM 对 commit 有非平凡影响，就按当前 AI policy 添加
`Assisted-by:` trailer，包含工具和主要模型；PR summary 也要单独披露 automation 使用。

## 5. 强制人工审核门

nixpkgs 要求 responsible person 在提交前人工审核。创建远端分支或 PR 前，向用户完整展示：

- 最终 diff；
- commit title、body 和 trailers；
- 成功、失败、跳过及未执行的验证；
- PR title 和完整 body；
- AI disclosure。

明确要求用户确认其理解改动、预期正确性和验证边界。收到明确确认前，只能保留本地 commit；
不得 push、创建 ready PR，或代替用户声称已经人工审核。若用户修改文案或代码，重新展示受
影响部分。

## 6. 推送和创建 PR

用户确认后：

1. 用 `gh auth status` 检查账号，确认 fork 确实属于目标账号且 parent 是
   `NixOS/nixpkgs`。
2. 推送 feature branch 到 fork。不要向 `NixOS/nixpkgs` 直接 push。
3. 若 workspace SSH 使用项目 deploy key，改用 HTTPS；若 Git 没有使用 `gh` 当前 token，
   可对单次 push 显式指定凭据 helper，且不得输出 token：

   ```bash
   git -c credential.helper= \
     -c 'credential.helper=!gh auth git-credential' \
     push -u fork <branch>
   ```

4. fork 创建或 push 返回 403 时，先用 GitHub API 只读检查 `viewerPermission`。权限确实
   不足时，请用户创建 fork、给 token 授权或重新登录；不要绕过权限创建无关联 repository。
5. 用 `gh pr create` 指定 `NixOS/nixpkgs`、`master`、用户 fork branch、已审核标题和正文。
   正文以当前官方 PR template 为基础，不保留不真实的勾选项。
6. 用 `gh pr view` 核对 URL、open/draft 状态、base/head、commit、body 和 disclosures；用
   `gh pr checks` 报告初始 CI 状态。

## 7. 合并后的本仓库回归

PR 创建不等于本地 workaround 已失效。只有上游 PR 合并、standalone-binaries 使用的
nixpkgs revision 包含修复、且目标平台重新验证后，才使用
`regress-patched-package-to-upstream` skill 删除本地 package override 并更新
`docs/regression/`。不要在上游 PR 尚未合并时提前删除保护路径。
