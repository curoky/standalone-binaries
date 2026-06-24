{
  lib,
  s6,
  symlinkJoin,
  s6-linux-init,
}:

let
  # The s6 store path (e.g. .../bin/s6-svscan) baked into the s6-linux-init
  # binary comes from s6's compiled-in S6_EXTBINPREFIX, which the shared skaware
  # builder sets via `--enable-absolute-paths`. Drop that flag from s6 and
  # rebuild s6-linux-init against it so no absolute s6 store path is embedded.
  s6NoAbsPaths = s6.overrideAttrs (oldAttrs: {
    configureFlags = lib.filter (f: f != "--enable-absolute-paths") oldAttrs.configureFlags;
  });

  # s6-linux-init also bakes its own $bin store path (e.g. .../bin/s6-linux-init-telinit)
  # into its binaries via the same `--enable-absolute-paths` flag. Drop it here too.
  patched =
    (s6-linux-init.override {
      s6 = s6NoAbsPaths;
    }).overrideAttrs
      (oldAttrs: {
        configureFlags = lib.filter (f: f != "--enable-absolute-paths") oldAttrs.configureFlags;
      });
in
symlinkJoin {
  name = "s6-linux-init";
  paths = [
    (lib.getOutput "out" patched)
    (lib.getOutput "bin" patched)
  ];
}
