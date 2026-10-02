# shadow — musl build workaround plus complete command packaging.
#
# Why local:
# 1. Stock enables optional libbsd support, but libbsd's `explicit_bzero` check
#    aborts under musl-static before shadow can build. Disable that feature while
#    retaining shadow's own checks.
# 2. Nixpkgs splits `su` into a separate output. The standalone command suite is
#    intentionally assembled with both outputs via `symlinkJoin`.
#
# Re-enable libbsd when its checks pass; keep the joined command layout.
{
  shadow,
  symlinkJoin,
}:

let
  portableShadow = shadow.override { withLibbsd = false; };
in
symlinkJoin {
  name = "shadow-${portableShadow.version}";
  paths = [
    portableShadow
    portableShadow.su
  ];
  meta = removeAttrs portableShadow.meta [ "outputsToInstall" ];
}
