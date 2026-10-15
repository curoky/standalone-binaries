# Artifact boundaries

通用目标见根 [AGENTS.md](../../AGENTS.md)。本页集中记录输出裁剪和已允许的例外；
修改这些产品边界前确认需求，再同步实现、校验和[定制记录](../regression/AGENTS.md)。

## Output selection

- FFmpeg 发布 headless 工具；恢复 codec、filter、采集或加速 feature 时重新验证完整
  静态依赖闭包和实际功能。
- PostgreSQL 发布 `psql` client；不恢复 server、扩展或无关开发工具。
- `clang-tools-*` 只提取 `clang-format`。多版本工具、runtime、插件和数据包按各自输出
  发布，不能因为上游构建已修好就删除产品包装。

## Dynamic libraries

Linux 只有 `nsight-systems` 允许 NVIDIA 的 glibc 动态发行物；interpreter 和 rpath 使用
宿主 ABI 路径，仍不得依赖 Nix store。例外在 `lib/make-artifacts.nix` 接入。

macOS 系统库只允许 `/usr/lib` 和 `/System/Library/Frameworks`。非系统依赖优先静态
链接；需要携带 dylib 时，install name 与 load command 使用 `@loader_path` 或
`@rpath`，rpath 限于 `@loader_path` 及其子目录。新增 dylib bundling 需确认。
Perl 已允许携带相对路径 `libperl.dylib`，见 [Perl](perl.md)。

Darwin arm64 Go/CGO 的特定 `libresolv.9.dylib` 路径由
[artifact](../../cmd/artifact/AGENTS.md#darwin-cgo-resolver) 修正，不能扩展到其他库或格式。
路径含 `openssl` 的文件免于 binary validation，但仍执行规范化；改变该豁免需确认。

## Host dependencies

- Darwin `git-filter-repo` 和 `netron` 使用宿主 `python3`。
- `eza-ls` 允许调用 `/bin/ls`。
- Java 工具使用外部 `JAVA_HOME`，见 [Java](java.md)。
- Podman 的服务、内核和宿主权限接口分别见
  [rootful](../../packages/podman/DESIGN.md) 与 [rootless](../../packages/podman-rootless/DESIGN.md)。

这些依赖仅适用于对应产品；新增宿主依赖需确认。

## Known gap

Darwin Rclone 使用 stock native Go，保留 `tzdata`、`mailcap` 和 `iana-etc` 资源 store
引用。这是已知可移植性缺口，只允许这三类资源，不放宽动态库或其他包的要求。
修复和验证范围见 [Go 资源路径](go.md#resource-paths)。
