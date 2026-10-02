# s6-rc — relocatable service compilation.
#
# Why local:
# 1. `s6-rc-compile` copies s6 and execline command prefixes into generated
#    service scripts, so it must use both local prefix-free dependencies.
# 2. Its own skaware absolute-path mode embeds s6-rc helper paths; disable it.
# 3. Configure independently hardcodes `S6RC_EXTLIBEXECPREFIX`, which embeds
#    `s6-rc-oneshot-run` and `s6-rc-fdholder-filler`; clear that macro while
#    retaining the inherited cross-build postConfigure work.
#
# Remove these changes when upstream generates services without store prefixes.
{
  lib,
  s6,
  execline,
  s6-rc,
}:

(s6-rc.override {
  inherit s6 execline;
}).overrideAttrs
  (oldAttrs: {
    configureFlags = lib.filter (f: f != "--enable-absolute-paths") oldAttrs.configureFlags;

    postConfigure = (oldAttrs.postConfigure or "") + ''
      sed -i 's|^#define S6RC_EXTLIBEXECPREFIX .*|#define S6RC_EXTLIBEXECPREFIX ""|' \
        src/include/s6-rc/config.h
    '';
  })
