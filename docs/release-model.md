# Release and cache

[build.yaml](../.github/workflows/build.yaml) 调用
[build-platform.yaml](../.github/workflows/build-platform.yaml)，各平台独立发现缺失包、
构建并发布。平台、runner、tag suffix 和排除项统一来自
[release-platforms.json](../.github/release-platforms.json)。
每个平台使用独立 package matrix，避免单个 matrix 超过 GitHub 的 256 job 限制。

## Artifacts

每个包的 `packages.<system>.<name>` 和 `tarballs.<system>.<name>` 是同一 derivation 的
`out` 与 `archive`：

| 输出 | 去向 |
| --- | --- |
| out、archive、source 的完整 closure | `ghcr.io/curoky/standalone-binaries-cache` |
| tar.gz | `ghcr.io/curoky/standalone-binaries:<name>-<architecture>` |

归档在 Nix build 内由 `lib/make-artifacts.nix` 生成，workflow 不修改内容或重新打包。
工具 manifest 包含单个 tar.gz layer，以及 `dev.curoky.standalone.system`、
`dev.curoky.standalone.out-path`、`dev.curoky.standalone.archive-path` annotations。
安装契约见 [Binman](../cmd/binman/AGENTS.md)，cache 协议见 [Nixcache](../cmd/nixcache/AGENTS.md)。

## Discovery and build

1. `discover` 从 GHCR 生成当前平台冻结的 cache index，作为保留一天的 Actions artifact
   交给同平台 build jobs。Index 只含已验证的 metadata，NAR 按需下载。
2. 普通模式 eval 当前平台 `cacheRoots`，通过 `nixcache serve --index` 检查每个包的
   out、archive、source roots，再用 `nixcache publication` 检查工具 artifact 身份。
3. 只有缓存与发布状态都匹配才跳过。任一缺失则进入 build matrix；远端查询错误使
   discovery 失败，不当作缓存缺失。
4. Build job 使用同一冻结 index，构建两项输出、上传 closure，再发布工具 artifact。
   Segment 的 `NIXCACHE_PACKAGE_KEY` 使用 matrix 包名；不能用 run ID 代替。
5. `summary` 汇总发现数量和构建结果。

缓存按确切 store path 跨 snapshot 复用。Lock 改变后未变的输出仍可命中；包名或版本相同
不能代替 path 相同。缓存就绪而工具发布失败时，下次用缓存补发。
冻结 index 不包含同一 run 后续上传的 segment，生命周期内由 build/prune 互斥保护。

Cache 不自行签名。CI 仅把固定 loopback URL
`http://127.0.0.1:37515?trusted=true` 设为 trusted substituter，不全局关闭签名校验。
`NIXCACHE_STORE` 的无 query URL 用于 readiness；`NIXCACHE_SUBSTITUTER` 用于 Nix 命令。

## Triggers

`push` 和 `schedule` 运行三个平台。手动触发可选择平台和包名；`*` 或空包名表示全部。

| 触发 | 候选范围 | 缓存与发布检查 |
| --- | --- | --- |
| push | 去掉 `exclude_pkgs` 和 `push_exclude_pkgs` 的包 | 检查 |
| schedule | 去掉 `exclude_pkgs` 的包 | 跳过，强制进入构建 |
| dispatch 全部 | 去掉 `exclude_pkgs` 的包 | 默认检查；`skip_discover=true` 时跳过 |
| dispatch 单包 | 所选平台中实际暴露该包的平台 | 只生成 index，直接构建 |

跳过探测时 summary 显示 `not-checked`。指定包在某平台不存在时跳过该平台，全部平台
都不存在则失败。`push_exclude_pkgs` 只控制普通 push 的慢包，不改变定时或手动支持。
单包 dispatch 不应用排除列表；不因此改变默认发布范围或 artifact 清理的保留集合。
包名单只维护在发布配置，[支持表](packages.md)展示其结果。
`clang-tools-*` 的 build job 另做磁盘释放与 swap 准备；发布流程与其他包一致。

## Cache cleanup

[prune-nix-cache.yaml](../.github/workflows/prune-nix-cache.yaml) 只允许手动触发，固定
checkout master，完整 eval 全平台 `cacheRoots`，包括慢包、排除聚合输出。
Eval 失败不删除。当前 roots 可达 closure 优先保留，其他候选经过至少 24 小时宽限期
并再次核对后删除；具体 retention 与 GC schema 见 Nixcache 文档。

Build 与 prune 共用 `nix-cache-lifecycle` concurrency group，`cancel-in-progress: false`，
整次运行互斥，matrix 内并行。GitHub 不保证 pending run 按 FIFO 执行；本地上传或清理
也须遵守单写者边界。

## Tool artifact cleanup

[过期产物清理](../.github/workflows/prune-obsolete-images.yaml) 固定读取 master，
按 `cacheRoots`、发布配置和独立工具名单生成当前 tag 集合。仅删除所有 tag 都有受管
平台 suffix、且全部不在当前集合中的 package version。
无 tag、非标准 tag、混有有效 tag 的 version 不属于候选。

包定义、发布配置或 artifact 实现变化的 push、每周定时和手动触发都会执行删除，结果
写入 summary。Eval、tag 集合生成或远端查询失败时停止；无 tag 版本由
[无 tag 清理 workflow](../.github/workflows/delete-untagged-images.yaml) 清理。
