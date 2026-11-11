# zonenow.tab 是发布时的时区分组；now.ck 用墙上时钟检查，DST 切换后
# 原本不同的组会合并，使同一源码稍后构建失败。仅把该检查的参考时间
# 固定为源码 SOURCE_DATE_EPOCH，保留全部时区数据与上游 checks。
# 上游默认用发布时刻执行 now.ck 后删除。
{ tzdata }:
tzdata.overrideAttrs (old: {
  checkFlags = (old.checkFlags or [ ]) ++ [ "CHECK_NOW_TIMESTAMP=$(SOURCE_DATE_EPOCH)" ];
})
