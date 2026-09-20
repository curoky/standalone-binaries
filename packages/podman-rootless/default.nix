{
  lib,
  stdenvNoCC,
  bash,
  coreutils,
  diffutils,
  gnugrep,
  gnused,
  podman,
}:

stdenvNoCC.mkDerivation {
  pname = "podman-rootless";
  inherit (podman) version;

  dontUnpack = true;
  dontFixup = true;

  installPhase = ''
    runHook preInstall

    mkdir -p "$out"
    cp -a ${podman}/. "$out/"
    chmod -R u+w "$out"

    # This package is an overlay on the matching rootful bundle. Keep its
    # compiled payload and common policy/configuration, replacing only files
    # whose rootless behavior differs.
    rm "$out/conf/podmanxd.service" "$out/conf/podmanxd.socket"
    rm "$out/libexec/podman/quadlet"
    rm -rf "$out/conf/networks"
    mkdir -p "$out/conf/networks"
    install -m755 ${./bin/install.sh} "$out/bin/install.sh"
    install -m755 ${./bin/podman} "$out/bin/podman"
    install -m755 ${./bin/podman-server} "$out/bin/podman-server"
    mkdir -p "$out/conf/s6-rc.d/podman"
    install -m644 ${./conf/s6-rc.d/podman/type} "$out/conf/s6-rc.d/podman/type"
    install -m644 ${./conf/s6-rc.d/podman/run} "$out/conf/s6-rc.d/podman/run"
    install -m644 ${./conf/s6-rc.d/podman/finish} "$out/conf/s6-rc.d/podman/finish"
    ln -sfn podman "$out/bin/docker"

    runHook postInstall
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [
    bash
    coreutils
    diffutils
    gnugrep
    gnused
  ];
  installCheckPhase = ''
    runHook preInstallCheck
    bash ${./tests/package.sh} "$out" ${podman}
    runHook postInstallCheck
  '';

  meta = podman.meta // {
    description = "Standalone Podman API service for one rootless user";
    mainProgram = "podman";
    outputsToInstall = [ "out" ];
    platforms = lib.platforms.linux;
  };
}
