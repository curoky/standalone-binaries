# Podman rootless — per-user service bundle derived from rootful Podman.
#
# Why local:
# 1. The rootful package carries systemd units, root-owned runtime paths and a
#    fixed bridge definition; those are the wrong lifecycle for one user.
# 2. Reuse the matching static Podman/helper payload, but remove rootful units,
#    Quadlet and the preseeded network before installing rootless wrappers.
# 3. The replacement launcher binds Podman to the user's ID-map and state, while
#    the installer publishes an s6 service definition instead of systemd state.
# 4. Package checks compare the derived payload with its rootful source so this
#    overlay cannot silently drop or diverge from shared backend tools.
#
# This is an independent product boundary, not an upstream build workaround.
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
