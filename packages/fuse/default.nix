# fuse2 — remove the non-static shadow dependency.
#
# Why local:
# 1. Stock substitutes `su` with an absolute `shadow.su` path. Besides embedding
#    a store path, shadow pulls in libbsd, whose `explicit_bzero` test aborts on
#    musl-static.
# 2. Fuse2 also selects full util-linux, whose login/su features reach the same
#    shadow dependency; fuse3 already uses util-linux-minimal.
# 3. `mount.fuse` only needs `su`, `mount` and `umount` at runtime, so the
#    override leaves `su` on PATH and supplies mount/umount from the minimal
#    util-linux package.
#
# Remove this override when fuse2's stock dependency closure is static-safe and
# does not compile a store path for `su`.
{
  fuse,
  runtimeShell,
  util-linuxMinimal,
  lib,
}:

fuse.overrideAttrs (oldAttrs: {
  preConfigure = ''
    substituteInPlace lib/mount_util.c \
      --replace-fail "/bin/mount" "${lib.getBin util-linuxMinimal}/bin/mount" \
      --replace-fail "/bin/umount" "${lib.getBin util-linuxMinimal}/bin/umount"
    substituteInPlace util/mount.fuse.c \
      --replace-fail "/bin/sh" "${runtimeShell}"

    export MOUNT_FUSE_PATH=$bin/bin
    export INIT_D_PATH=$TMPDIR/etc/init.d
    export UDEV_RULES_PATH=$TMPDIR/etc/udev/rules.d
  '';
})
