# execline — remove compiled store prefixes.
#
# Why local:
# 1. The skaware builder enables absolute paths, so execline binaries compile
#    sibling-command locations such as `multisubstitute` and `pipeline` under
#    the Nix output. Disable that prefix so commands resolve through PATH.
# 2. Configure still hardcodes `EXECLINE_SHEBANGPREFIX` into scripts generated
#    by s6-rc. A kernel shebang must be absolute, so use `/usr/bin/env -S` to
#    resolve `execlineb -P` through PATH while preserving its option.
#
# Remove these changes when upstream can generate relocatable command prefixes
# and shebangs.
{
  lib,
  execline,
}:

execline.overrideAttrs (oldAttrs: {
  configureFlags = lib.filter (f: f != "--enable-absolute-paths") oldAttrs.configureFlags;

  postConfigure = ''
    sed -i 's|^#define EXECLINE_SHEBANGPREFIX .*|#define EXECLINE_SHEBANGPREFIX "/usr/bin/env -S "|' \
      src/include/execline/config.h
  '';
})
