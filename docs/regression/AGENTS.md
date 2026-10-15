# Package customizations

记录当前 pin、构建修正、资源包装和例外，供 agent 判断哪些可以移除。
人查平台支持用 [Package support](../packages.md)；这里不记录发布成功状态。

| 范围 | 记录 |
| --- | --- |
| x86_64 Linux 本地定制、两个 Linux 平台共用的 manifest 选择 | [linux.md](linux.md) |
| ARM64 Linux 的平台停用 | [linux-aarch64.md](linux-aarch64.md) |
| macOS ARM64 定制 | [darwin.md](darwin.md) |

## Table fields

- `定制`：📌 pin；🩹 构建或路径修正；📦 资源、runtime 或输出包装；⚠️ 动态例外；⏸️ 停用。
- `回归`：✅ 可尝试整项移除；🟡 可尝试部分移除或恢复平台；❌ 保留产品行为；⏳ 例外审计。
  这些符号表示处理方式，不表示构建通过或失败。一次失败不使修正变成永久产品约定。
- `原因与保留边界`：一句话说明当前问题和必须保留的行为，详细原因留在实现旁。
- `回归判据`：删除修正前要验证的结果。
- `已测 unstable`：最后一次实际测试移除修正所用的 unstable 短 rev；未测填 `—`。
- `来源`：选择或实现路径。公共修正和内部依赖单独列行，名称未必是 flake package attr。

跨平台定制分别登记。内部依赖也保留记录，验证时构建其消费方；取消独立发布不代表
修正已删除。ARM64 Linux 不使用其他表中的本地包或 build-tool overlay。

## Updating records

新增或改变定制时同步对应行。移除步骤按
[maintain-packages](../../.agents/skills/maintain-packages/SKILL.md) 执行。

批量处理先取候选：

```bash
rg '^\| .+ \| (✅|🟡)' docs/regression/*.md
```

- 整项成功后删行；部分成功只删已解决的问题；只剩产品包装时保留行并改为 `❌`。
- 失败时保留候选，按新证据纠正原因和判据。
- 得到明确构建结果后才刷新 `已测 unstable`；eval、经过 patch 的普通构建或公共修正的
  部分成功不算移除验证。公共修正须全部通过，或得到仍需保留的明确失败证据。
- 相同 rev 且相关代码、配置与测试范围未变时，批量任务可复用记录；用户要求重测则重测。
- 产品明确不支持的平台不进入恢复队列；只为构建失败而停用的平台可以重试。
