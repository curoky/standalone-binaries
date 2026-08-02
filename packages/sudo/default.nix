# sudo — fully-static musl build (Linux only).
#
# The stock `pkgsStatic.sudo` is fail-closed: its `buildInputs = [ pam ]` and
# pam carries `meta.badPlatforms = [ isStatic ]`, so the static build is
# rejected before it starts. PAM cannot be statically linked here (and a
# portable, unprivileged tarball has no PAM stack to talk to anyway), so drop
# the pam dependency and configure `--disable-pam`. The result is a standalone
# musl-static `sudo`.
#
# Note: this ships a relocatable binary only. Privilege escalation still
# requires the setuid-root bit to be applied out of band (the tarball install
# path is unprivileged and cannot preserve setuid); `--version` and `--help`
# work without it.
{
  lib,
  sudo,
}:

# pam is the sole `isStatic` badPlatform source and cannot be statically
# linked. Replace it with null via `.override` so the derivation no longer
# references it (which is what pins the badPlatform / fail-closed evaluation),
# then disable PAM at configure time.
(sudo.override { pam = null; }).overrideAttrs (old: {
  buildInputs = lib.remove null (old.buildInputs or [ ]);

  configureFlags = (old.configureFlags or [ ]) ++ [ "--disable-pam" ];
})
