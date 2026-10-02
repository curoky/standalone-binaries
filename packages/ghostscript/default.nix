# ghostscript — select the static headless executable target.
#
# Why local:
# 1. Nixpkgs' headless derivation still selects Ghostscript's shared-library
#    build and install targets, which fail with the static stdenv.
# 2. Ghostscript's regular target already produces the standalone `gs` needed
#    here, so clear the shared target flags without patching source.
# 3. The headless build intentionally has no `gsx` X11 launcher; remove only
#    that assertion from the inherited install check and retain the `gs` checks.
#
# Remove this override when `pkgsStatic.ghostscript_headless` selects the static
# executable and its matching checks itself.
{
  lib,
  stdenv,
  ghostscript,
}:

let
  staticGhostscript = ghostscript.override (
    {
      cupsSupport = false;
      x11Support = false;
      dynamicDrivers = false;
    }
    // lib.optionalAttrs stdenv.hostPlatform.isDarwin {
      fontconfig = null;
    }
  );
in
staticGhostscript.overrideAttrs (oldAttrs: {
  configureFlags =
    (oldAttrs.configureFlags or [ ])
    ++ lib.optionals stdenv.hostPlatform.isDarwin [
      "--disable-fontconfig"
    ];

  buildFlags = [ ];
  installTargets = [ "install" ];

  postInstall =
    lib.replaceStrings
      [
        ''
          ln -s gsc "$out"/bin/gs
        ''
      ]
      [ "" ]
      oldAttrs.postInstall;

  installCheckPhase =
    lib.replaceStrings
      [
        ''
          $out/bin/gsx --version
        ''
      ]
      [ "" ]
      oldAttrs.installCheckPhase;
})
