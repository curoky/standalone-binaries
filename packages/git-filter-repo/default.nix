# git-filter-repo — Python payload with a relocatable launcher.
#
# Why local:
# 1. The nixpkgs entry point is wrapped with its Nix Python environment, leaving
#    interpreter and module paths that cannot be used after relocation.
# 2. Copy the application modules and underlying script into the package rather
#    than preserving that generated wrapper.
# 3. Launch with sibling Python 3.14 on Linux or the explicitly supported system
#    `python3` boundary on macOS, using package-relative module paths.
#
# This is intentional runtime packaging, not an upstream build workaround.
{
  stdenv,
  writeText,
  python3Packages,
}:

let
  wrapperScript = writeText "wrapper.sh" ''
    #!/usr/bin/env bash

    script_path="$(readlink -f "$0")"
    root=$(cd "$(dirname "$script_path")" && pwd)/..
    store=$root/..

    if [[ "$(uname)" == "Darwin" ]]; then
      exec -a "$0" python3 "$root/bin/_git_filter_repo_main.py" "$@"
    else
      export PYTHONHOME=$store/python314
      export PYTHONPATH=$PYTHONHOME/lib/python3.14
      export PYTHONPATH=$PYTHONPATH:$PYTHONHOME/lib/python3.14/site-packages
      export PYTHONPATH=$PYTHONPATH:$PYTHONHOME/lib/python3.14/lib-dynload
      export PYTHONPATH=$PYTHONPATH:$root/lib/python3.14/site-packages
      exec -a "$0" "$PYTHONHOME/bin/python3.14" "$root/bin/_git_filter_repo_main.py" "$@"
    fi
  '';
in

stdenv.mkDerivation {
  pname = "git-filter-repo";
  inherit (python3Packages.git-filter-repo) version;

  dontUnpack = true;

  installPhase = ''
    mkdir -p $out/lib/python3.14/site-packages
    cp -r ${python3Packages.git-filter-repo}/${python3Packages.python.sitePackages}/* \
      $out/lib/python3.14/site-packages/

    mkdir -p $out/bin
    cp ${python3Packages.git-filter-repo}/bin/.git-filter-repo-wrapped \
      $out/bin/_git_filter_repo_main.py
    cp ${wrapperScript} $out/bin/git-filter-repo
    chmod +x $out/bin/git-filter-repo
  '';
}
