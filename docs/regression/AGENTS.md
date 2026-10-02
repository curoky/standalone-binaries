# 上游回归清单

本目录只维护回归队列，不解释 patch 实现。包级原因和保留边界以最终 derivation 的 Nix
注释为准；公共 workaround 以其组件实现和 `AGENTS.md` 为准。

- [`linux.md`](linux.md)：x86_64-linux 本地定制及两个 Linux 平台共用的 upstream
  manifest 选择。
- [`linux-aarch64.md`](linux-aarch64.md)：aarch64-linux upstream-only 边界及
  manifest 差异。
- [`darwin.md`](darwin.md)：aarch64-darwin 的定制。

跨平台包分别登记。公共 workaround 使用稳定候选 ID，并在「来源」中指向实现；候选 ID
不一定是 package attr。

经确认有较大希望整项回到 upstream 的纯包级 workaround 可以放在
`packages/regression/<name>/`。这只是与回归队列对应的物理归档，不是 package family；
目录内各 package 仍分别接线和回归，也不设置聚合 `default.nix`。

## 列约定

- `回归`：✅ 整项回到 upstream；🟡 只回归 workaround；❌ 结构性 packaging；⏳ 长期例外。
- `定制`：📌 pin；🩹 build/portability patch；📦 packaging；⚠️ 动态例外；⏸️ 临时停用。
- `原因与保留边界`：只写足以识别待回归部分的一句话，不复制 Nix 注释。
- `回归判据`：只写删除定制前必须成立的结果，不记录操作过程或历史验证。
- `commit`：最后一次在该平台实际回归测试所用的 `nixpkgs-unstable` 短 rev；未测填 `—`。
- `来源`：只列选择或实现路径，不附原因说明。

索引文件可以保留平台或生态分组标题，但不得承载包级原因。实际构建过且得到明确成功或
失败证据后才刷新 `commit`；普通 patched build 或部分公共 workaround 样本不算回归验证。

## 批量回归

按表格顺序处理 `✅` 和 `🟡`：

```bash
rg '^\| .+ \| (✅|🟡)' docs/regression/*.md
```

整项成功后删行；部分成功只删除已失效的 workaround；失败则保留并把一句话判据修正得更
准确。新增或改变 pin、本地 derivation、override、公共 workaround、禁用检查或例外时，
同步更新对应平台表。
