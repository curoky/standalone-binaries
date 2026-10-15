# Build tools

构建时执行的 compiler、generator、解释器和测试工具必须在 build platform 上运行。
产物运行期 helper 以及生成 target code 的工具按 target 选择；不能仅按工具名替换。
Linux musl cross 构建可复用 build 平台的 glibc Rust/LLVM，避免重编大型工具链。

## Native inputs

nixpkgs 通过 splicing 选择依赖平台；组合 derivation、内部 scope 或错误的依赖分类可能
丢失这层信息。先检查失败工具实际所属平台和执行阶段。

[static-build-tools.nix](../../packages/static-build-tools.nix) 在 producer 处
注入当前 channel 的 native build tools。它只应用于 x86_64 Linux 和 Darwin 正式包。
不要把整个 `pkgsStatic.python3`、`pkgsStatic.perl` 或其 package set 改成 native，
否则会破坏静态 runtime 和需要 target interpreter library 的包。

[native-input 检查](../../lib/validate-native-build-inputs.nix) 递归检查
正式包的 native inputs：有 `stdenv` 的 input，其 host platform 必须等于 consumer 的
build platform。它不能推断误放进 `buildInputs` 的工具角色，这类问题仍需修 producer。
ARM64 Linux 使用 raw package set，但运行门禁；probe 两者都不应用。

## Local overlays

`pkgsStatic.extend` 也会影响 `buildPackages`。只为静态 target 添加的 override 必须限制为：

```nix
if pkg.stdenv.hostPlatform.isStatic then pkg.overrideAttrs overrides else pkg
```

修改后检查 target 仍应用修正、`buildPackages` 对应包的 `drvPath` 不变、正式包 eval
通过门禁，并用 `nix build .#<name> --dry-run` 检查意外的 LLVM/rustc/CMake 重编。
最后实际构建目标并检查产物；dry-run 只用于检查构建计划。

运行期解释器、PostgreSQL 的 target compiler 和 Rizin 的 target assembler 都有明确用途，
不能为了缩小构建闭包而替换成 native。具体修正及删除条件见实现和
[定制记录](../regression/AGENTS.md)。
