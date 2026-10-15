# Java

Java 工具使用外部 JDK。Wrapper 从 `JAVA_HOME` 显式执行 `java`，根据自身路径定位
包内 JAR 和 classpath；不打包 JDK，也不从宿主 PATH 选择 Java。

JAR、脚本和数据无需静态链接。随包提供的 native helper 仍须满足 Linux musl-static
或 macOS 动态库规则；需要重编时按
[maintain-packages](../../.agents/skills/maintain-packages/SKILL.md) 处理。

验证 wrapper 能在外部 JDK 下启动搬迁后的 JAR，并检查每个 native helper 的链接和运行。
