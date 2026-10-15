# 为静态包选择构建期工具；不替换 target runtime。
#
# 当前问题与修正：
# - Graphite2/Rizin 的组合 Python 环境丢失 splice metadata，Node/rsync 的
#   hooks 也需执行 Python。向 producer 注入 native Python。
# - Wget、Rizin、Radare2 将生成工具放进 target 依赖；注入 native Perl。
# - Mise 的 checks 需执行 Git；注入 native gitMinimal。
# - Skaware scope 在正常 splicing 前解析 pkg-config；在 scope 内注入 native 工具。
# - Go compiler 的三项资源 patch 将 tzdata/MIME/IANA store 路径嵌入 consumer；
#   仅移除这些 patch，保留其余 compiler 行为。
#
# 仅在 static target scope 应用，避免 extend 同时修改 buildPackages。
# 上游正确选择 build tools 后逐项删除对应 override；Go override 在资源查找恢复
# 标准路径后删除。保留 target Python/Perl 及其 package set 的静态语义。
{
  goBuildPkgs,
  lib,
  nativePkgs,
}:
_: prev:
let
  useNativeBuildTools = name: tools: {
    "${name}" = prev.${name}.override tools;
  };
  withoutNixDataPathPatches =
    go:
    go.overrideAttrs (oldAttrs: {
      patches = builtins.filter (
        patch:
        let
          name = builtins.baseNameOf (toString patch);
        in
        !(lib.hasInfix "-iana-etc-" name || lib.hasInfix "-mailcap-" name || lib.hasInfix "-tzdata-" name)
      ) oldAttrs.patches;
    });
  usePortableGoBuilder =
    builder: compiler:
    lib.optionalAttrs (builtins.hasAttr builder prev && builtins.hasAttr compiler goBuildPkgs) {
      "${builder}" = prev.${builder}.override {
        go = withoutNixDataPathPatches goBuildPkgs.${compiler};
      };
    };
in
lib.optionalAttrs prev.stdenv.hostPlatform.isStatic (
  lib.optionalAttrs prev.stdenv.hostPlatform.isLinux (
    usePortableGoBuilder "buildGoModule" "go"
    // usePortableGoBuilder "buildGoLatestModule" "go_latest"
    // usePortableGoBuilder "buildGo123Module" "go_1_23"
    // usePortableGoBuilder "buildGo125Module" "go_1_25"
    // usePortableGoBuilder "buildGo126Module" "go_1_26"
    // usePortableGoBuilder "buildGo127Module" "go_1_27"
  )
  // lib.optionalAttrs (prev ? graphite2) (
    useNativeBuildTools "graphite2" { python3 = nativePkgs.python3; }
  )
  // lib.optionalAttrs (prev.stdenv.hostPlatform.isLinux && prev ? mise) (
    useNativeBuildTools "mise" { git = nativePkgs.gitMinimal; }
  )
  // lib.optionalAttrs (prev.stdenv.hostPlatform.isLinux && prev ? nodejs-slim_24) (
    useNativeBuildTools "nodejs-slim_24" { python3 = nativePkgs.python3; }
  )
  // lib.optionalAttrs (prev.stdenv.hostPlatform.isLinux && prev ? nodejs-slim_26) (
    useNativeBuildTools "nodejs-slim_26" { python3 = nativePkgs.python3; }
  )
  // lib.optionalAttrs (prev.stdenv.hostPlatform.isLinux && prev ? radare2) (
    useNativeBuildTools "radare2" { perl = nativePkgs.perl; }
  )
  // lib.optionalAttrs (prev.stdenv.hostPlatform.isLinux && prev ? rizin) (
    useNativeBuildTools "rizin" {
      perl = nativePkgs.perl;
      python3 = nativePkgs.python3;
    }
  )
  // lib.optionalAttrs (prev.stdenv.hostPlatform.isLinux && prev ? skawarePackages) {
    skawarePackages = prev.skawarePackages.overrideScope (
      _: skawarePrev: {
        buildPackage = skawarePrev.buildPackage.override {
          pkg-config = nativePkgs.pkg-config;
        };
      }
    );
  }
  // lib.optionalAttrs (prev.stdenv.hostPlatform.isDarwin && prev ? rsync) (
    useNativeBuildTools "rsync" { python3 = nativePkgs.python3; }
  )
  // lib.optionalAttrs (prev.stdenv.hostPlatform.isDarwin && prev ? wget) (
    useNativeBuildTools "wget" { perlPackages = nativePkgs.perlPackages; }
  )
)
