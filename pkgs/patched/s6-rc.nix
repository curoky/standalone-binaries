{
  lib,
  s6,
  execline,
  s6-rc,
}:

# s6-rc bakes absolute store paths into its binaries (and into the service
# definitions s6-rc-compile generates), both for s6 (via <s6/config.h>) and for
# itself (via the shared skaware builder's `--enable-absolute-paths` flag).
#
# - `s6` and `execline` are passed in already patched (see pkgs/patched/s6.nix
#   and pkgs/patched/execline.nix) and MUST be wired back in via `override`,
#   because s6-rc-compile bakes the prefixes from <s6/config.h> and
#   <execline/config.h> into the service scripts it emits at compile time.
# - Drop `--enable-absolute-paths` so s6-rc's own paths rely on $PATH instead.
(s6-rc.override {
  inherit s6 execline;
}).overrideAttrs
  (oldAttrs: {
    configureFlags = lib.filter (f: f != "--enable-absolute-paths") oldAttrs.configureFlags;

    # S6RC_EXTLIBEXECPREFIX is always set to the absolute $libexecdir (the s6-rc
    # configure script hardcodes it regardless of --enable-absolute-paths). It is
    # baked into the s6-rc-oneshot-run / s6-rc-fdholder-filler references that
    # s6-rc-compile emits into generated service scripts. Blank it out so those
    # helpers are looked up via $PATH instead of an absolute store path.
    #
    # Keep the upstream postConfigure (cross-compile header rewrite) intact.
    postConfigure = (oldAttrs.postConfigure or "") + ''
      sed -i 's|^#define S6RC_EXTLIBEXECPREFIX .*|#define S6RC_EXTLIBEXECPREFIX ""|' \
        src/include/s6-rc/config.h
    '';
  })
