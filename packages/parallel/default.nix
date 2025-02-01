{
  lib,
  parallel,
  perl,
  writeText,
}:

let
  # Wrapper for the bundled perl scripts. At deploy time it runs the real
  # script (renamed `_<name>`) under the sibling `perl` package, falling back
  # to a system perl. The script's own directory is prepended to PATH so the
  # scripts that shell out to a bare `parallel` (e.g. parsort) find the wrapped
  # one next to them.
  wrapperScript = writeText "wrapper.sh" ''
    #!/usr/bin/env bash

    script_path="$(readlink -f "$0")"
    bindir=$(cd "$(dirname "$script_path")" && pwd)
    store=$bindir/../..

    name=$(basename "$0")
    # `sem` is a symlink to `parallel`; the real script is `_parallel` and it
    # switches to sem mode based on $0. Fall back to `_parallel` for any name
    # without a matching `_<name>` script.
    target=$bindir/_$name
    [[ -f $target ]] || target=$bindir/_parallel
    export PATH=$bindir:$PATH
    if [[ -f $store/perl/bin/perl ]]; then
      exec -a "$0" $store/perl/bin/perl "$target" "$@"
    else
      exec -a "$0" "$target" "$@"
    fi
  '';
in

parallel.overrideAttrs (oldAttrs: {
  nativeBuildInputs = (oldAttrs.nativeBuildInputs or [ ]) ++ [ perl ];
  postInstall = (oldAttrs.postInstall or "") + ''
    # The main program ships as `.parallel-wrapped` (the real perl script) plus a
    # nixpkgs bash PATH-wrapper named `parallel`. Drop that wrapper and treat the
    # real script like the others.
    mv $out/bin/.parallel-wrapped $out/bin/parallel
    rm -f $out/bin/sem
    chmod +w $out/bin

    # Re-wrap every bundled perl script to run under a sibling/system perl.
    for name in parallel niceload parcat parsort sql; do
      mv $out/bin/$name $out/bin/_$name
      cp ${wrapperScript} $out/bin/$name
      chmod +x $out/bin/$name
    done

    ln -s parallel $out/bin/sem
  '';
})
