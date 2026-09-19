# rsync (Darwin) — static build with native build/check tools.
#
#   - `python3`/`libiconv` are overridden to native: darwin's
#     `pkgsStatic.python3` is marked broken (its interpolation in `preBuild`
#     would fail the whole package set at eval).
#   - `nativeCC` is added to checkInputs: with `strictDeps` the
#     `partial-protected-regular-retry-policy` test needs a `cc -dynamiclib` on
#     PATH, which the cross set does not provide.
#   - `install_name_tool` retargets libiconv to the system
#     `/usr/lib/libiconv.2.dylib`: the static Darwin libiconv otherwise bakes a
#     Nix store i18n data dir into rsync.
{
  rsync,
  python3,
  libiconv,
  nativeCC,
}:

(rsync.override {
  inherit python3 libiconv;
}).overrideAttrs (oldAttrs: {
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
