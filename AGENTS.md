# standalone-binaries

## Core goals

把 nixpkgs 软件构建成可搬运目录和确定性 tar.gz，在没有 Nix 的机器上运行。
优先使用 unstable 上游包，只维护构建和可移植性所必需的本地定制。
用户查包看 [Package support](docs/packages.md)。

## Key conventions

- Linux ELF 使用 musl 全静态链接。macOS 只加载系统库或包内相对路径 dylib。
  程序、脚本、资源和 helper 不得依赖运行机器的 `/nix/store`。
  已有例外集中在[产物边界](docs/package-strategies/special-cases.md)，新增或改变例外需确认。
- 支持 `x86_64-linux`、`aarch64-linux`、`aarch64-darwin`。ARM64 Linux 只接入
  stock nixpkgs 包，允许选择 channel、output 和别名；不维护本地 patch、override 或 wrapper。
  stock 构建失败时停用该平台。
- `packages/upstream.nix` 选择上游包，默认 unstable、静态、`out`；省略默认字段。
  `packages/default.nix` 显式接入本地包，并覆盖同名上游包。索引只负责选择和接线。
  仅供其他包使用的依赖放在内部 `let`，不单独生成产物。
- 本地定制复用上游 derivation。文件头写清当前问题、修正及删除条件；资源包装、同级
  runtime、多版本输出等产品行为另说明保留理由。具体构建规则见[包构建](docs/package-strategies/AGENTS.md)。
- 新增或改变包、平台、pin、patch、wrapper 或例外时，同步[支持表](docs/packages.md)和
  [定制记录](docs/regression/AGENTS.md)，核对 `.github/release-platforms.json` 的发布排除项。
- 先验证受影响目标。构建成功后检查链接、搬迁和实际运行；eval、缓存命中、实际编译、
  smoke test 分别报告。涉及其他平台时，在目标环境验证后再删除其修正。
- `bm` 安装 tar.gz，不解析包依赖；同级 runtime 需分别安装。Nix cache 与工具发布分别
  判断完成状态。修改归档、OCI 或 cache 协议时同步消费方、workflow 和[发布模型](docs/release-model.md)。
- 沟通默认用中文，先报告结果、证据和剩余问题。已明确的目标与授权继续执行；需要确认时
  给出具体改动、原因和选择，不重复询问。Commit 不添加 `Co-authored-by`。
- 文档只保留当前规则。根文档负责目标和入口，组件 `AGENTS.md` 负责契约，skill 负责流程，
  实现旁注释负责原因；各处使用相对链接，不重复包名单、参数表或测试历史。

## Workflows

| 工作 | 入口与 skill |
| --- | --- |
| 接入包、修构建或运行问题、更新 nixpkgs、删除 patch/pin | [maintain-packages](.agents/skills/maintain-packages/SKILL.md) |
| 给 nixpkgs 提交修复、处理已有 PR 的 review 或检查是否已被上游覆盖 | [submit-nixpkgs-fix](.agents/skills/submit-nixpkgs-fix/SKILL.md) |
| 在 Linux ARM64 / macOS ARM64 上构建、运行或复现问题 | [github-actions-arm-debug](.agents/skills/github-actions-arm-debug/SKILL.md) |
| 修改包选择、manifest schema 或 flake outputs | `lib/`、`flake.nix`，先读[包构建](docs/package-strategies/AGENTS.md) |
| 修改产物整理、校验与归档 | [cmd/artifact/AGENTS.md](cmd/artifact/AGENTS.md) |
| 修改安装器 `bm` | [cmd/binman/AGENTS.md](cmd/binman/AGENTS.md) |
| 修改 Nix cache | [cmd/nixcache/AGENTS.md](cmd/nixcache/AGENTS.md) |
| 修改 CI、发布或清理 | [发布模型](docs/release-model.md)、对应 workflow |

组件改动按各目录的验证命令执行；无需为普通组件开发另建 skill。
