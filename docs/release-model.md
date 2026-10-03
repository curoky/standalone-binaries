# 发布与 Cache 模型

`.github/workflows/build.yaml` 是 Linux 和 Darwin 的统一发布入口。它按平台调用
`.github/workflows/build-platform.yaml`，各平台独立按当前 `outPath` 发现缺失包，构建
standalone 目录及归档，再分别发布 Nix cache 和工具 OCI artifact。

平台与 runner 映射固定为：

| Nix system | Runner | Artifact suffix |
| --- | --- | --- |
| `x86_64-linux` | `ubuntu-latest` | `linux-x86_64` |
| `aarch64-linux` | `ubuntu-24.04-arm` | `linux-arm64` |
| `aarch64-darwin` | `macos-26` | `darwin-arm64` |

平台、artifact suffix、发布排除项和独立工具包名统一定义在
`.github/release-platforms.json`。构建和过期 artifact 清理都读取该文件，修改发布平台或
排除项时不得在 workflow 内另建一份配置。

每个平台使用独立的动态 package matrix，不能把多个平台的包展开到同一个 matrix。这样既让
平台失败相互独立，也避免触及 GitHub Actions 单个 matrix 的 256 job 上限。

Nix cache 的 segment schema、serving 和 retention 细节见
[`cmd/nixcache/AGENTS.md`](../cmd/nixcache/AGENTS.md)。

## 发布流程

1. `discover` 从 GHCR 生成一次当前平台的冻结 cache index；普通模式再 eval 当前平台的
   `cacheRoots`，包含各包 out、archive 和 source roots，排除聚合输出。
2. 普通模式由本地 `nixcache serve --index` 作为 GHCR-backed substituter，分别检查当前
   out、archive、source roots；另用 `nixcache publication` 核对工具 artifact 的输出身份。
3. 仅当缓存 roots 和发布状态都匹配时跳过；任一缺失的包进入 build matrix。
4. `discover` 将冻结 index 作为单日 Actions artifact 传给同平台全部 matrix leg；每个 build
   job 直接加载该 index，避免并发重复读取全部 segment metadata。
5. 每个包构建 `packages.<system>.<name>` 和
   `tarballs.<system>.<name>`。两者是同一 multi-output derivation 的 `out` 与
   `archive` output。
6. standalone、archive 和 source 输出的 closure 推送到 cache repository；归档另发布为
   `ghcr.io/curoky/standalone-binaries:<name>-<arch>`，单 layer 布局不变。工具 manifest 标注
   `dev.curoky.standalone.system`、`dev.curoky.standalone.out-path` 和
   `dev.curoky.standalone.archive-path`，精确关联当前输出。
7. `summary` 汇总发现数量和各 matrix leg 的最终状态。

归档必须由 `lib/make-artifacts.nix` 在 Nix build 内生成。workflow 不得自行重新打包或修改
归档内容。

Cache segment 使用 matrix package 名作为稳定的 `NIXCACHE_PACKAGE_KEY`。Prune 据此在增量
run 中按 package 保留最新 segment；不得改用 run ID 或 snapshot 内的 tag 数量表示 package
identity。

## Cache 命中判定

命中判定只使用当前 `flake.lock` 和包定义产生的确切 `outPath`。`serve` 读取同平台所有
现存 snapshot 的 segment；snapshot 只决定上传归属和 retention 分组，不隔离读取。
因此 lock 改变后，未改变的 outPath 仍可命中；不同 outPath 不按包名或版本替代。

未指定 `--index` 的 live `serve` 进程在内存中复用已验证的不可变 segment，每 5 分钟列举
tag，只读取新增项，移除已删除项并原子更新索引。刷新失败保留完整旧索引；NAR payload
仍按需下载。

CI 的 build job 使用 `discover` 生成的冻结 index，不执行上述 live refresh。该 index
只包含已验证的 narinfo 与 NAR descriptor，NAR payload 仍按需从 GHCR 下载；build 和 prune
的 concurrency 边界保证其使用期间 segment 不会被清理。冻结视图不包含同一 run 内新上传的
segment，这只减少跨 matrix leg 的临时复用，不影响构建与发布正确性。

缓存命中不代表发布成功：cache 上传成功但 artifact 发布失败时，下次仍进入 job，用缓存
补发。旧 artifact 缺少身份 annotations 也进入发布；远端查询错误终止 discovery。Archive
进入 Nix cache 以避免补发时重新打包，代价是跨两个 repository 的额外存储，不能假设去重。

仅缓存和发布均就绪才跳过。以下情形跳过两类探测并强制构建候选范围（summary 显示
`not-checked`，不是 0 命中）：

- `schedule` 触发（每周定时全量刷新）；
- `workflow_dispatch` 且 `skip_discover=true`。

本地 cache 不签名。Workflow 仅将固定的 loopback URL
`http://127.0.0.1:37515?trusted=true` 作为 trusted substituter；不得通过
`require-sigs=false` 全局接受其他未签名 cache。`NIXCACHE_STORE` 保留无 query 的 URL，
只用于 readiness HTTP 请求；Nix 命令使用 `NIXCACHE_SUBSTITUTER`。

## 触发矩阵

`push` 和 `schedule` 始终运行全部三个平台。`workflow_dispatch` 的 `platform` 输入可选择
`all`、`x86_64-linux`、`aarch64-linux` 或 `aarch64-darwin`，默认 `all`。
`skip_discover` 是 `workflow_dispatch` 的布尔输入；`name` 是包名字符串输入（`*` 或空
表示全部包）。

| 触发 | `discover` job | 候选范围 | cache 命中过滤 | build matrix 来源 |
| --- | --- | --- | --- | --- |
| `push` | 运行 | 全部包 | 做 | `discover` 输出 |
| `schedule` | 运行 | 全部包 | 跳过（强制重建） | `discover` 输出 |
| dispatch 全部，普通 | 运行 | 全部包 | 做 | `discover` 输出 |
| dispatch 全部，强制 | 运行 | 全部包 | 跳过 | `discover` 输出 |
| dispatch 具体包 | 只生成 index | 仅该包 | 不适用 | `discover` 输出 |

具体包 dispatch 先在入口 workflow 验证所选平台是否暴露该包，再由各平台的 `discover`
输出单包 matrix，不做 cache 与 publication 探测。不存在该包的平台显示为 skipped，其他
平台继续；如果所有所选平台都不可用，入口 job 失败，避免错误包名静默成功。新增触发方式
或改变选择语义时，必须同步两个 build workflow 和本表。

Linux-only Node.js runtime 和同级 runtime 工具（`nodejs-slim*`、`markdownlint-cli2`、
`opencommit`、`prettier`）以及 `pnpm`、`nil`、`nixfmt`、`shellcheck`、`gdb`、
`clang-tools-{18..23}` 编译慢，仅在 `push` 触发时通过平台配置的 `push_exclude_pkgs`
从候选中排除，避免拖慢普通代码 push。其中 Node.js runtime 与同级工具、`nil`、`nixfmt`、
`gdb`、`clang-tools-*` 只在 Linux 暴露，Darwin 的排除列表相应更短。`schedule` 和
`workflow_dispatch` 不受此排除影响，仍会构建并发布它们。改动 `push_exclude_pkgs`
时须同步 `.github/release-platforms.json` 和本说明。

`clang-tools-{18..23}`（原 `build-llvm-tools.yaml`）已并入 Linux workflow 的普通
`discover` / build matrix，与其他包共用 cache 命中过滤和 artifact 发布契约。它们是
LLVM/clang 大型构建，build job 仅对 `clang-tools-*` 的 matrix leg 额外执行释放磁盘和
配置 swap 的准备步骤，且已随上文列入 `PUSH_EXCLUDE_PKGS`（push 时跳过）。`lld_*` 与
`clang*` 仍通过 `EXCLUDE_PKGS` 排除（只作为构建输入暴露，不单独发布）。
`.github/workflows/prune-nix-cache.yaml` 只允许手动触发，固定 checkout master 并完整 eval
`.#cacheRoots`（全部平台和全部包，含慢包，排除聚合输出），任一失败不执行删除。当前
roots 的可达 closure 优先保护，历史规则之外的候选至少等待 24 小时并再次确认才删除。

Build 和 prune 共用 `nix-cache-lifecycle` concurrency group，`cancel-in-progress: false`，
整次运行互斥、matrix 内仍并行。GitHub concurrency 不保证 pending run 的 FIFO 排队，新
pending 可能替换旧 pending；这不是持久任务队列。手动本地上传/清理也必须遵守单写者边界。

## Artifact 清理

`.github/workflows/prune-obsolete-images.yaml` 清理由改名或删除遗留的工具 OCI artifact。
它固定 checkout master，按 `.github/release-platforms.json` 的平台 suffix 和发布排除项从
`cacheRoots` 生成当前 tag 集合，并额外保留 `binman`、`nixcache` 等独立 workflow 产物。
只有全部 tag 都带受管平台 suffix、且全部不在当前集合中的 package version 才是删除候选；
无 tag、非标准 tag、同时包含新旧 tag 的 version 均不由该 workflow 删除。

该 workflow 在包定义、发布配置或 artifact 实现发生 push 时运行，并在每周日 06:00 UTC
定时运行，也允许手动触发；三类触发都会直接删除候选，并把结果写入 job summary。
`cacheRoots` eval、当前 tag 集合生成或远端查询任一步失败都不得执行删除。无 tag 版本仍由
`.github/workflows/delete-untagged-images.yaml` 独立清理。
