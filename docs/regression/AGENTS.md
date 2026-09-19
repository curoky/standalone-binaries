# 上游回归清单

本目录是 agent 维护的 pin、包级及公共组件 patch 与本地 packaging 总账，也是批量回归的唯一输入。

按平台/架构拆成三张表：

- [`linux.md`](linux.md)：跨架构共享的 Linux 表（x86_64-linux 与 aarch64-linux 通用），每行只列该平台有定制的包。
- [`linux-aarch64.md`](linux-aarch64.md)：仅 aarch64-linux 特有的差异（当前是临时停用的包）。共享行不在此重复。
- [`darwin.md`](darwin.md)：macOS 表。

跨平台包在对应的多张表里各出现一次。

公共 workaround 也必须在对应平台表中单独登记，用稳定的组件候选 ID 标识，并在「来源」
指向共享实现；候选 ID 不一定是 package attr，不能直接拼成 `nix build .#<ID>`。
从包级集中到 artifact 或其他公共层不代表上游回归成功，不得因此移出批量候选。
当前 Darwin resolver 的移除操作见
[`darwin.md`](darwin.md#darwin-cgo-resolver-回归)。

## 状态含义（`回归` 列）

- ✅ **整项候选**：优先尝试直接回到 unstable 上游；标记只表示值得验证，不表示已经构建成功。
- 🟡 **部分候选**：只回归临时 workaround，必须保留表中写明的 packaging 或产品行为。
- ❌ **结构性保留**：当前不是上游回归目标；用于说明本地包为何存在，避免误删。
- ⏳ **长期审计**：动态或预编译例外；只有出现满足仓库产物不变量的替代方案时才处理。

## 定制含义（`定制` 列）

📌 表示旧 nixpkgs pin，🩹 表示编译或 portability patch，📦 表示结构性 packaging，
⚠️ 表示动态例外，⏸️ 表示临时停用。

## commit 语义

`commit` 记录最后一次在该平台做回归测试时 `flake.lock` 里 `nixpkgs-unstable` 的 rev（短 hash），
未测过填 `—`。审计时若该 commit 与当前 `flake.lock` 的 unstable rev 相同，说明该平台在当前 channel
已测过、可跳过；rev 变化后需重新验证。`原因与保留边界` 只给一句摘要，完整失败原因与保留边界记在
「来源」列指向的 nix 文件（或公共实现）注释里，回归时以那里为准。
公共 patch 只有在绕过自身后完成其回归判据，或得到仍需保留的明确失败证据，才更新 commit；
经过 patch 后的成功构建及部分成功样本不算公共 patch 的移除回归。

## 批量回归

批量回归按表格顺序遍历 `✅` 和 `🟡` 行：

```bash
rg '^\| .+ \| (✅|🟡)' docs/regression/*.md
```

回归成功后，整项回归删除该行；部分回归更新原因与判据，只保留尚未解决的部分，并刷新 commit。
跨平台包在某个平台回归成功后只删该平台表中的行，其他平台/架构的行保留。新增或改变非 unstable pin、
本地 derivation、override、公共 workaround、禁用检查或动态例外时，必须同步维护本目录。
