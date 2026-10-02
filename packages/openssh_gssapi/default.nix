# OpenSSH with GSSAPI — relocatable cross-architecture service bundle.
#
# Why local:
# 1. Scp and sshd need sibling ssh/session/auth helpers. Replace their compiled
#    or PATH-based discovery with wrappers that resolve helpers from the moved
#    package.
# 2. QEMU user mode cannot execute OpenSSH's seccomp pre-auth sandbox, while the
#    rlimit sandbox terminates the cross-architecture service before handshake.
#    Configure no sandbox for the supported host-loopback deployment.
#
# Both choices are product boundaries for this package rather than a general
# upstream regression candidate.
{
  lib,
  stdenv,
  fetchurl,
  openssh_gssapi,
  writeText,
}:

let
  wrapperScriptScp = writeText "wrapper.sh" ''
    #!/usr/bin/env bash

    script_path="$(readlink -f "$0")"
    root=$(cd "$(dirname "$script_path")" && pwd)/..

    exec -a "$0" "$root/bin/_scp" -S $root/bin/ssh "$@"

  '';
  wrapperScriptSshd = writeText "wrapper.sh" ''
    #!/usr/bin/env bash

    script_path="$(readlink -f "$0")"
    root=$(cd "$(dirname "$script_path")" && pwd)/..

    exec -a "$0" "$root/bin/_sshd" \
      -o SshdSessionPath="$root/libexec/sshd-session" \
      -o SshdAuthPath="$root/libexec/sshd-auth" \
      "$@"
  '';
in

openssh_gssapi.overrideAttrs (oldAttrs: {
  configureFlags = (oldAttrs.configureFlags or [ ]) ++ [
    "--with-sandbox=none"
  ];

  postInstall = (oldAttrs.postInstall or "") + ''
    mv $out/bin/scp $out/bin/_scp
    cp ${wrapperScriptScp} $out/bin/scp
    chmod +x $out/bin/scp

    mv $out/bin/sshd $out/bin/_sshd
    cp ${wrapperScriptSshd} $out/bin/sshd
    chmod +x $out/bin/sshd
  '';
})
