# GNU Parallel — Perl entry points with a sibling runtime.
#
# Why local:
# 1. Nixpkgs wraps the Perl commands with an interpreter and module environment
#    from the Nix store, which cannot be used after relocation.
# 2. Preserve every real script under a private name and install one uniform
#    wrapper for `parallel`, `sem`, `niceload`, `parcat`, `parsort` and `sql`.
# 3. Resolve sibling commands through the package bin directory and execute the
#    separately installed standalone Perl from the shared package store.
#
# This is intentional runtime packaging, not an upstream build workaround.
{
  lib,
  parallel,
  perl,
  writeText,
}:

let
  wrapperScript = writeText "wrapper.sh" ''
    #!/usr/bin/env bash

    script_path="$(readlink -f "$0")"
    bindir=$(cd "$(dirname "$script_path")" && pwd)
    store=$bindir/../..

    name=$(basename "$0")
    export PATH=$bindir:$PATH
    exec -a "$0" $store/perl/bin/perl "$bindir/_$name" "$@"
  '';
in

parallel.overrideAttrs (oldAttrs: {
  nativeBuildInputs = (oldAttrs.nativeBuildInputs or [ ]) ++ [ perl ];
  postInstall = (oldAttrs.postInstall or "") + ''
    mv $out/bin/.parallel-wrapped $out/bin/parallel
    rm -f $out/bin/sem
    chmod +w $out/bin

    ln -s _parallel $out/bin/_sem

    for name in parallel sem niceload parcat parsort sql; do
      [ -e $out/bin/_$name ] || mv $out/bin/$name $out/bin/_$name
      cp ${wrapperScript} $out/bin/$name
      chmod +x $out/bin/$name
    done
  '';
})
