# `pkgsStatic.extend` 的 Target 边界

Linux 的 `pkgsStatic` 是 musl cross package set：target 产物使用 musl-static，build 平台仍使用
glibc 工具链。`pkgsStatic.extend` 会同时影响 target 包和 `buildPackages` 中的同名包。

只为静态 target 准备的 override 必须限定在
`pkg.stdenv.hostPlatform.isStatic`：

```nix
onlyStatic =
  pkg: overrides:
  if pkg.stdenv.hostPlatform.isStatic then pkg.overrideAttrs overrides else pkg;
```

否则对 `libuv` 等依赖的修改会进入 build 平台闭包，改变 `cmake`、LLVM 和 rustc 的
`drvPath`，导致本可 substitute 的工具链重新编译。

## Build-tool splicing 门禁

nixpkgs 会按依赖位置选择 `__spliced.buildHost`，但 `python3.withPackages` 等组合 derivation
可能丢失 splice metadata，使 target-static Python 留在 `nativeBuildInputs`；有些 upstream
expression 也会把仅构建期执行的 Perl 放进 `buildInputs`。同一规则适用于 compiler、linker、
assembler、code generator、build system 和测试工具：只要工具会在构建期间执行，就必须能在
build platform 上运行；为 target 生成代码或作为产品运行期 helper 的工具仍属于 target。
正式包集合通过
[`packages/static-build-tools.nix`](../../packages/static-build-tools.nix)
在 producer 边界统一注入当前 channel 的 native build tool。不得把整个
`pkgsStatic.python3`、`pkgsStatic.perl` 或对应 package set 改成 native，否则会破坏静态
runtime 和需要链接 target interpreter library 的包。

[`lib/validate-native-build-inputs.nix`](../../lib/validate-native-build-inputs.nix)递归检查正式
source closure：具有 `stdenv` 的 native input，其 host platform 必须与 consumer 的 build
platform 一致。该门禁无法推断 `buildInputs` 中某个解释器是否只在构建期执行，因此这类
upstream 误分类必须在 producer override 中明确登记。新增例外前应先修正 producer 的
dependency splicing。Probe 使用未应用上述修正与门禁的 raw package set，继续代表 stock
upstream 行为。

当前正式闭包中保留的 target-static interpreter 只有两类运行期依赖：`iproute2` 的独立
Python scripts output，以及 `groff` 的 Perl tools output（由 `man` 闭包引入）。它们不是
build tool，不得为了减少构建闭包而替换成 native interpreter。

## Patched package toolchain 边界

只对回归清单中已有 patch/override 的 package root 做 build-tool 归属审计，不为 stock
upstream 包预先增加 override。Mise 的 Git check tool 通过公共 producer override 使用
native package set；其余非解释器工具链不需要新的共享 override：

- CMake bootstrap 和 Rizin 的 Meson native compiler 已通过 `depsBuildBuild` 选择 build
  platform compiler；
- Catatonit 的 install check 使用 build-for-build binutils，Codex 使用 native
  Clang/libclang，rsync 使用 native check compiler；
- smartmontools 的 autoreconf/hostname 已来自 native package set；
- PostgreSQL 的 `gccAsClang` 是有意生成 target code 的 compiler，不能替换成普通 native
  compiler；
- Rizin 的 binutils 被编入 x86/PPC assembler backend，属于运行期 target assembler，不是
  build tool，不能加入 native build-tool overlay。其 standalone helper relocation 应作为独立
  runtime packaging 问题处理。

## 验证

修改局部 overlay 后检查：

- target 包仍应用静态构建 override；
- `buildPackages` 中对应包保持 upstream `drvPath`；
- 正式 artifact 求值通过 native-input platform 门禁；
- `nix build .#<package> --dry-run` 不包含意外的 LLVM、rustc 或 CMake 源码构建；
- 最终 target 产物仍通过静态链接校验。

Node.js 的具体应用见
[`packages/nodejsPackages/nodejs/26.nix`](../../packages/nodejsPackages/nodejs/26.nix)。
