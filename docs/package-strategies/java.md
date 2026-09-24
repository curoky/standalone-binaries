# Java 工具打包策略

Java 工具不打包 JDK：运行期使用外部 JDK，包内非 Java 部分走纯静态编译。后续所有
Java 工具都遵循本约定。具体包清单和定制状态以实现及[回归清单](../regression/AGENTS.md)为准。

## 外部 JDK

本仓库不构建、不携带 JDK，也不对 JDK 做静态编译。JDK 由用户自行安装到自定义位置
（官方发行的动态链接 JDK 即可）。wrapper 通过 `JAVA_HOME` 定位并显式执行外部
`java`，不写死绝对路径，也不依赖宿主 `PATH` 上的 `java`。

这是明确的产品边界：Java 工具的运行期 JVM 依赖外部 JDK，等同于其他生态里对宿主
解释器的显式依赖。JDK 不进入产物运行期闭包，因此不受产物不变量的静态链接约束。

## 包内非 Java 部分

包内除 JAR、脚本和资源外的一切原生组件（工具自带的 C/C++ native、helper ELF 等）
仍必须满足全部产物不变量：

- Linux 常规 ELF 使用 musl 全静态链接；
- 不残留 `/nix/store` 运行期引用，并通过严格 ELF 门禁；
- native 不因随包 JDK 而豁免——JDK 在包外，native 静态化边界不变。

需要重编上游预编译 native 时只修 root cause，优先最小 override，并按
[patch-nixpkgs-standalone](../../.trae/skills/patch-nixpkgs-standalone/SKILL.md) 迭代。
不得为规避 native 静态化而把工具降级为动态 ELF 例外。

## Wrapper 与资源

按相对资源 wrapper 模式：真实入口重命名，wrapper 根据自身路径定位包内 JAR 和资源，
不写入 build-time store path。wrapper 只负责求出 `JAVA_HOME` 下的 `java` 并携带包内
classpath 启动，上游 shebang 和绝对路径不参与运行期解析。

新增 Java 工具必须至少 smoke test：在外部 JDK 下 wrapper 能启动 shipped JAR，且包内
native 通过静态校验。
