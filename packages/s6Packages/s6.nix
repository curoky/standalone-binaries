# s6 — remove compiled store prefixes.
#
# Why local:
# 1. The skaware builder's absolute-path mode compiles sibling commands such as
#    `s6-supervise` under the Nix output. Disable that prefix so PATH is used.
# 2. Configure independently hardcodes `S6_LIBEXECPREFIX`, causing
#    `s6-ftrig-listen` to embed the store path of `s6-ftrigrd`. Clear it after
#    configure.
# 3. Wire in the local prefix-free execline explicitly; accepting it as a
#    function argument alone would not change s6's dependency.
#
# Remove these changes when upstream supports relocatable prefixes throughout.
{
  lib,
  s6,
  execline,
}:

(s6.override { inherit execline; }).overrideAttrs (oldAttrs: {
  configureFlags = lib.filter (f: f != "--enable-absolute-paths") oldAttrs.configureFlags;

  postConfigure = ''
    sed -i 's|^#define S6_LIBEXECPREFIX .*|#define S6_LIBEXECPREFIX ""|' \
      src/include/s6/config.h
  '';
})
