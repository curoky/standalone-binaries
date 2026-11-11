# Atuin 的 SQLx proc macro 在 build 平台加载 SQLite/OpenSSL；stock cross
# derivation 将 target musl 库用于 proc macro，且遗漏 native zlib。为 host
# pkg-config 单独选择 build-platform 库，保留 target 静态依赖与全部检查。
# 上游正确区分 SQLx host/target 库后删除。
{
  lib,
  atuin,
  nativePkgs,
}:
atuin.overrideAttrs (old: {
  nativeBuildInputs = old.nativeBuildInputs ++ [
    nativePkgs.pkg-config
    nativePkgs.sqlite
    nativePkgs.openssl
    nativePkgs.zlib
  ];
  env = (old.env or { }) // {
    HOST_PKG_CONFIG = lib.getExe nativePkgs.pkg-config;
  };
})
