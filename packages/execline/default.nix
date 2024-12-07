{
  lib,
  execline,
}:

# execline programs (e.g. backtick, forbacktickx, if) exec into sibling
# execline tools (multisubstitute, pipeline, importas, exit, ...) via the
# EXECLINE_BINPREFIX macro. The shared skaware builder's `--enable-absolute-paths`
# flag makes that prefix an absolute /nix/store path. Drop it so the binaries
# rely on $PATH instead of an absolute store path.
execline.overrideAttrs (oldAttrs: {
  configureFlags = lib.filter (f: f != "--enable-absolute-paths") oldAttrs.configureFlags;

  # EXECLINE_SHEBANGPREFIX is always set to the absolute $shebangdir (hardcoded
  # by execline's configure regardless of --enable-absolute-paths). It is baked
  # into <execline/config.h> and used by s6-rc-compile to emit "#!<prefix>execlineb"
  # shebang lines. A shebang must be an absolute path (the kernel does not search
  # $PATH), so point it at /usr/bin/env and let env resolve execlineb via $PATH.
  postConfigure = ''
    sed -i 's|^#define EXECLINE_SHEBANGPREFIX .*|#define EXECLINE_SHEBANGPREFIX "/usr/bin/env "|' \
      src/include/execline/config.h
  '';
})
