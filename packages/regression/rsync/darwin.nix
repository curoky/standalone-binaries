# rsync (Darwin) — static build with native build/check tools.
#
# Why local:
# 1. Darwin `pkgsStatic.python3` is marked broken and would fail during
#    evaluation when interpolated by rsync's build hooks. Use native Python only
#    as a build tool.
# 2. Under `strictDeps`, the partial-protected retry test needs a native
#    `cc -dynamiclib`, which the cross input set does not put on PATH. Add it to
#    check inputs.
# 3. The static Darwin libiconv carries a Nix i18n data path. Use native iconv
#    and retarget its load command to `/usr/lib/libiconv.2.dylib`.
#
# Remove each override when stock rsync builds, tests and links without Nix
# paths on Darwin.
{
  rsync,
  python3,
  libiconv,
  nativeCC,
}:

(rsync.override {
  inherit python3 libiconv;
}).overrideAttrs
  (oldAttrs: {
    nativeCheckInputs = (oldAttrs.nativeCheckInputs or [ ]) ++ [ nativeCC ];

    postInstall = (oldAttrs.postInstall or "") + ''
      oldIconv=$(otool -L "$out/bin/rsync" | awk '/\/nix\/store\/.*libiconv/ { print $1 }')
      if [ -n "$oldIconv" ]; then
        install_name_tool \
          -change "$oldIconv" /usr/lib/libiconv.2.dylib \
          "$out/bin/rsync"
      fi
    '';
  })
