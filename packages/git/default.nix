# git — reduced musl-static build with relocatable resources.
#
# Why local:
# 1. Python, Perl, NLS and manuals expand the static closure but are not part of
#    this CLI product, so the local derivation disables them.
# 2. Git's static link does not receive all private libraries from curl and its
#    HTTP stack. Add the missing archives explicitly and force the final link to
#    static mode.
# 3. The all-static closure collides with Git's generic global `error` symbol.
#    Rename Git's definition and call sites to `git_error` before compilation.
# 4. The install checks have locale-dependent failures in the musl environment,
#    so they remain disabled until the stock suite passes there.
# 5. Git compiles template and exec directories under its output. The wrapper
#    derives both paths from its installed location after relocation.
#
# The build and test changes are regression candidates; the relative resource
# wrapper is permanent packaging.
{
  lib,
  stdenv,
  fetchurl,
  writeText,
  git,
  nghttp2,
  libpsl,
  c-ares,
  brotli,
}:

let
  wrapperScript = writeText "wrapper.sh" ''
    #!/usr/bin/env bash

    script_path="$(readlink -f "$0")"
    root=$(cd "$(dirname "$script_path")" && pwd)/..

    if [[ -z $GIT_TEMPLATE_DIR ]]; then
      export GIT_TEMPLATE_DIR="$root/share/git-core/templates"
    fi

    if test -n "$NO_SET_GIT_TEMPLATE_DIR"; then
      unset GIT_TEMPLATE_DIR
    fi

    if [[ -z $GIT_EXEC_PATH ]]; then
      export GIT_EXEC_PATH="$root/libexec/git-core/"
    fi

    exec -a "$0" "$root/bin/_git" "$@"
  '';
in
(git.override {
  pythonSupport = false;
  nlsSupport = false;
  perlSupport = false;
  withManual = false;
}).overrideAttrs
  (oldAttrs: rec {
    buildInputs = oldAttrs.buildInputs ++ [
      nghttp2
      libpsl
      c-ares
      brotli
    ];

    doInstallCheck = false;

    env.NIX_LDFLAGS =
      oldAttrs.env.NIX_LDFLAGS
      + " -static -lnghttp2 -lnghttp3 -lcares -lngtcp2 -lngtcp2_crypto_ossl -lpsl -lssl -lcrypto -lssh2 -lidn2 -lzstd -lz -lunistring -lbrotlidec -lbrotlicommon";

    patchPhase = ''
      find . -path './t/t[0-9][0-9][0-9][0-9]' -prune -o -type f -name '*.[ch]' -exec sed -i 's/\<error\>(/git_error(/g' {} +
      find . -path './t/t[0-9][0-9][0-9][0-9]' -prune -o -type f -name '*.[ch]' -exec sed -i 's/\<error\>\s\+(/git_error (/g' {} +
      find . -path './t/t[0-9][0-9][0-9][0-9]' -prune -o -type f -name '*.[ch]' -exec sed -i 's/int\s\+error\s*(/int git_error(/g' {} +
      find . -path './t/t[0-9][0-9][0-9][0-9]' -prune -o -type f -name '*.[ch]' -exec sed -i 's/undef error\b/undef git_error/' {} +
    '';

    preInstallCheck = oldAttrs.postInstall;

    postInstall = (oldAttrs.postInstall or "") + ''
      mv $out/bin/git $out/bin/_git
      cp ${wrapperScript} $out/bin/git
      chmod +x $out/bin/git

      mkdir -p contrib/subtree
      echo "all:" > contrib/subtree/Makefile
      echo "install:" >> contrib/subtree/Makefile
      echo "install-doc:" >> contrib/subtree/Makefile
    '';
  })
