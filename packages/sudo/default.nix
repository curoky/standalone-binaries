# sudo — PAM-free musl-static build.
#
# Why local:
# 1. Stock `pkgsStatic.sudo` depends on PAM, whose metadata rejects static hosts,
#    so evaluation fails before compilation.
# 2. A relocatable tarball has no packaged PAM stack, so the override removes
#    PAM and configures sudo without it instead of bypassing the platform guard.
# 3. The artifact intentionally does not preserve setuid-root; deployments that
#    need privilege escalation must apply that permission out of band.
#
# Remove the build override if PAM becomes static-safe, but retain the explicit
# deployment boundary for setuid.
{
  lib,
  sudo,
}:

(sudo.override { pam = null; }).overrideAttrs (old: {
  buildInputs = lib.remove null (old.buildInputs or [ ]);

  configureFlags = (old.configureFlags or [ ]) ++ [ "--disable-pam" ];
})
