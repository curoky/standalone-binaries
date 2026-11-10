# 每个平台的导出名只能来自一个集合；检查包名时即报错，不强制求值 derivation。
{ lib }:
system: sets:
let
  origins = lib.zipAttrs (
    lib.mapAttrsToList (source: packages: lib.mapAttrs (_: _: source) packages) sets
  );
  collisions = lib.filterAttrs (_: sources: lib.length sources > 1) origins;
in
if collisions != { } then
  throw "package name collisions on ${system}: ${
    lib.concatStringsSep "; " (
      lib.mapAttrsToList (name: sources: "${name} (${lib.concatStringsSep ", " sources})") collisions
    )
  }"
else
  lib.mergeAttrsList (builtins.attrValues sets)
