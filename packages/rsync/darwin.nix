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
