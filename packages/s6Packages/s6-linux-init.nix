# s6-linux-init — relocatable generated init tree.
#
# Why local:
# 1. Its binaries inherit s6's compiled executable prefix, so the local
#    prefix-free s6 must be wired in explicitly.
# 2. `s6-linux-init-maker` copies execline's prefix into every generated init
#    and handler script, so it must also use the local prefix-free execline.
# 3. The package's own skaware flags compile absolute paths such as
#    `s6-linux-init-telinit`; disable those as well.
# 4. Nixpkgs splits the required payload between `out` and `bin`; `symlinkJoin`
#    intentionally publishes both as one standalone package.
#
# The three prefix changes are regression candidates; the joined output is
# permanent packaging.
{
  lib,
  s6,
  execline,
  symlinkJoin,
  s6-linux-init,
}:

let
  patched = (s6-linux-init.override { inherit s6 execline; }).overrideAttrs (oldAttrs: {
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
