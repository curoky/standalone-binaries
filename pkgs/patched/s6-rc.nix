{
  lib,
  s6,
  s6-rc,
}:

# s6-rc bakes absolute store paths into its binaries (and into the service
# definitions s6-rc-compile generates), both for s6 (via <s6/config.h>) and for
# itself (via the shared skaware builder's `--enable-absolute-paths` flag).
#
# - `s6` is passed in already patched (see pkgs/patched/s6.nix) and MUST be wired
#   back in via `override`, because the s6 path is embedded at compile time.
# - Drop `--enable-absolute-paths` so s6-rc's own paths rely on $PATH instead.
(s6-rc.override { inherit s6; }).overrideAttrs (oldAttrs: {
  configureFlags = lib.filter (f: f != "--enable-absolute-paths") oldAttrs.configureFlags;
})
