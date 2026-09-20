# Stock pkgsStatic.shadow enables optional libbsd support. On musl-static,
# libbsd's explicit_bzero check aborts with SIGABRT before shadow can build.
# Disable that optional feature instead of skipping dependency tests, while
# retaining shadow's own checks. Upstream splits `su` into a separate output,
# so merge it back into the standalone command suite.
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
  # The joined derivation only has `out`; inheriting Shadow's multi-output
  # install selection would make Nix request a nonexistent `man` output.
  meta = removeAttrs portableShadow.meta [ "outputsToInstall" ];
}
