# GH 的 token refresh 测试加载 America/New_York，但 stock 未声明测试时区
# 数据；可搬运 Go compiler 不再注入 store tzdata 路径后，沙箱测试失败。
# 仅在 checks 设置 ZONEINFO，保留 runtime 的系统时区查询和全部测试。
# 上游显式提供测试时区数据后删除。
{ gh, tzdata }:
gh.overrideAttrs (old: {
  nativeCheckInputs = old.nativeCheckInputs ++ [ tzdata ];
  preCheck = (old.preCheck or "") + ''
    export ZONEINFO=${tzdata}/share/zoneinfo
  '';
})
