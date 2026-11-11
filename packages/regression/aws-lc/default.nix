# AWS-LC 的 symbol generator 和 SSL test runner 是纯 Go 构建工具；stock
# 从 static target set 取 Go，在 Linux 混用 target CC，在 Darwin 重编 Go
# 时缺少 libresolv。使用原生 Go，并仅为这些构建工具禁用 CGO；Darwin
# 的 goDeps vendor fetch 也使用 native buildGoModule，不构建 target Go SDK。
# 上游正确选择 build-platform Go/CC 后删除；保留 target 库与 SSL checks。
{
  aws-lc,
  go,
  buildGoModule,
}:
(aws-lc.override { inherit go buildGoModule; }).overrideAttrs (old: {
  env = (old.env or { }) // {
    CGO_ENABLED = "0";
  };
})
