# conmon — static dependency closure.
#
# Why local:
# 1. Stock conmon propagates `systemd-minimal`.
# 2. systemd is marked unsupported on static hosts, so evaluation fails before
#    conmon can build even though this configuration links only glib/seccomp.
# 3. The override keeps those direct libraries and clears propagated inputs.
#
# Remove this override when stock `pkgsStatic.conmon` no longer propagates
# systemd.
{
  lib,
  stdenv,
  fetchurl,
  conmon,
  glib,
  libseccomp,
  pkg-config,
}:

conmon.overrideAttrs (oldAttrs: rec {
  buildInputs = [
    glib
    libseccomp
  ];
  propagatedBuildInputs = [ ];
})
