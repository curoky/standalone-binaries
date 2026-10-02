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

  # nixpkgs always selects the shared-library targets. They cannot link with
  # the static stdenv, while Ghostscript's regular targets produce the
  # standalone `gs` executable that this repository needs.
  buildFlags = [ ];
  installTargets = [ "install" ];

  # The static install already provides bin/gs, so retain only the upstream
  # Resource/font installation from postInstall.
  postInstall =
    lib.replaceStrings
      [
        ''
          ln -s gsc "$out"/bin/gs
        ''
      ]
      [ "" ]
      oldAttrs.postInstall;

  # gsx is the X11 launcher and is intentionally absent from the headless
  # build. Keep the upstream gs version and rendering checks.
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
