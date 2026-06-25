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
})
