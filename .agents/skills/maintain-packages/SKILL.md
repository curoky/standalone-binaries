---
name: maintain-packages
description: 维护 standalone-binaries 的包；用于接入或停用平台、修复构建和运行路径、更新 nixpkgs、验证并移除本地 patch、override 或版本 pin。覆盖从上游探测到最终产物验证和文档同步。
---

# Maintain packages

先读根 [AGENTS.md](../../../AGENTS.md) 和[包构建](../../../docs/package-strategies/AGENTS.md)，
再按问题读取对应专题；不要一次加载所有生态文档。

## 1. 确定目标

1. 查看工作区差异，保留已有改动。确认包名、目标平台和用户要求的行为。
2. 在 `packages/upstream.nix` 查 attr、alias、channel、output、平台，再检查
   `packages/default.nix` 是否有同名覆盖。按最终 derivation 的注释和
   [定制记录](../../../docs/regression/AGENTS.md) 了解当前修正。
3. 按任务选择下面的接入/修复或删除定制流程。现有代码与记录冲突时，以代码和当前验证
   更新记录；只有含义不清且会改变产品行为时才询问。

## 2. 接入或修复

先用锁定的 unstable 探测未修改的上游包：

```bash
nix build .#probe.<system>.unstable.<attr>
```

- 能完成构建和运行验证：在 `packages/upstream.nix` 接入，省略默认字段。
- ARM64 Linux 失败：记录原因并停用该平台；不新增本地修正。需要验证旧 channel 时仍用
  stock 包，pin 写入 manifest。
- 其他平台失败：保留实际错误，定位编译、测试、链接或运行路径问题，再加最小定制。

优先修正依赖角色和构建参数，其次替换为静态依赖、关闭无法静态构建的可选 feature，
最后处理相对资源与同级 runtime。不要复制上游完整 derivation，也不要为了使构建通过
无依据地关闭检查。纯脚本不需要静态链接，但其解释器和资源必须可定位。

可由 nixpkgs 修复替代的构建、依赖 workaround 放在 `packages/regression/<name>/`；
长期的 wrapper、资源布局和产品配置留在普通包目录。仅内部使用的依赖不加入返回的
包集合，仍在定制记录中跟踪其修正。

Linux 使用 musl-static；macOS 优先静态链接非系统依赖，包内 dylib 按
[产物边界](../../../docs/package-strategies/special-cases.md) 处理。
Go/CGO 是否可关闭要以功能和产物验证决定。构建期工具问题按
[Build tools](../../../docs/package-strategies/build-tools.md) 修复，避免改变 target runtime。

## 3. 删除定制或更新 nixpkgs

更新 lock 时只更新本次目标 channel，例如 `nix flake update nixpkgs-unstable`；
精确版本 pin 按其用途保留，不随 channel 更新一并替换。

1. 用户指定包时检查对应记录；批量处理按[定制记录](../../../docs/regression/AGENTS.md)
   的 `✅` / `🟡` 行逐项进行。更新 lock 后复用这份清单。
2. 确定待删除部分。构建修正和故障 pin 可移除；wrapper、资源、多版本输出和产品配置
   按现有行为保留。一个包兼有两者时，只测试删除构建修正。
3. 在一次性工作副本中去掉目标 patch/pin 或替换接线，用同一 lock 构建正式输出。
   Probe 可先探路；外部 `nixpkgs#pkgsStatic.<attr>` 不等于本仓库构建环境。
4. 公共修正必须在禁用该项修正的条件下验证全部受影响包，保留其他处理和校验。
   任一明确失败即可证明仍需保留；删除需要全部通过。不要添加永久 bypass 参数。
   Darwin resolver 的专属步骤见 [Artifact](../../../cmd/artifact/AGENTS.md#removing-the-resolver-fix)。
5. 完成下一节验证后，只删除已经通过的平台或修正。整包恢复上游时删除本地接线及孤立
   文件，改由 manifest 接入；部分恢复时缩小 override。缺少目标平台环境时保留该平台
   修正，使用 [ARM 验证](../github-actions-arm-debug/SKILL.md) 完成测试。

## 4. 验证最终输出

```bash
nix build .#packages.<system>.<name>
nix build .#tarballs.<system>.<name> --out-link result-archive
```

把归档解压到不同目录后验证：

- Linux：对入口和 helper 用 `file`、`readelf -l -d` 检查静态 ELF、无动态 interpreter
  或依赖；musl 来源还需核对构建 package set。`file` 本身不能证明 libc 种类。
- macOS：对所有 Mach-O 用 `otool -L` / `otool -l` 检查依赖和 rpath，修改 load command
  后用 `codesign --verify --strict` 验证签名。
- 运行 `--version` 及涉及改动的功能。Wrapper 必须验证资源、CA、helper 和同级 runtime；
  仅能启动不足以证明资源路径正确。检查没有实际运行期 `/nix/store` 依赖。

先验证目标，再按影响范围执行 `nix flake check`、`nix build .#all-fast` 或组件测试。
记录执行平台、命令、成功/失败阶段和未验证项；区分 source 构建与 artifact 校验。

## 5. 同步与交付

- 更新 derivation 头部的当前问题、修正和删除条件，删掉已失效的注释。
- 更新[定制记录](../../../docs/regression/AGENTS.md)及[支持表](../../../docs/packages.md)。
  平台或包名变化时核对 `.github/release-platforms.json`，删除失效排除项。
  支持表按平台接线标记上游、本地定制和 pin；默认发布排除项不单独标记。
  表格按软件自身支持范围和明确的产品族平台边界分为跨平台、Linux-only 和 macOS-only；
  单纯构建失败或尚未接入只在对应平台标记为未接入，不改变分组。内部依赖不列入支持表；
  独立工具以各自 workflow 为准。包名可用下面命令读取：

  ```bash
  nix eval --json .#sources \
    --apply 'builtins.mapAttrs (_: builtins.attrNames)'
  ```

- 修改共享规则或协议时更新其所属文档；不把包级流水写回根 `AGENTS.md`。
- 报告改动和实际验证。上游通用问题需提交 nixpkgs 时，再用
  [submit-nixpkgs-fix](../submit-nixpkgs-fix/SKILL.md)。
