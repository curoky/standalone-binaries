# Podman 5 — self-contained rootful container-engine bundle.
#
# Why local:
# 1. The Podman 5 product pins the latest 5.x maintenance source (5.8.9) while reusing unstable's
#    derivation and dependencies. Unstable now provides 6.x; the older channel's
#    full closure fails to build target Python/tzdata through iproute2.
# 2. Stock static Podman propagates systemd and installs its unit/tmpfiles
#    payload. Systemd is unavailable in the static set and the final service is
#    installed from this bundle, so remove that dependency and generated state.
# 3. Nixpkgs exposes runc through a generated wrapper. Copying that launcher
#    would retain store paths, so restore the wrapped file as the actual static
#    runc executable before Podman packages its helpers.
# 4. Stock fixup wraps Podman and helper lookup with Nix paths. Disable it, copy
#    the complete helper set into `libexec/podman`, and supply static nftables
#    plus BusyBox applets from the same bundle.
# 5. Podman 5 otherwise searches host paths for catatonit, seccomp policy,
#    registries and signature policy. The four source patches make the bundled
#    paths authoritative where configuration or environment variables cannot.
# 6. Certificates, configuration and the remote/server launchers are installed
#    beside the binary; focused checks exercise those exact packaged paths.
#
# Regress the systemd and runc build workarounds independently. The helper,
# major version, configuration and resource layout are the rootful product boundary.
{
  lib,
  fetchFromGitHub,
  gpgme,
  crun,
  runc,
  conmon,
  catatonit,
  coreutils,
  busybox,
  nftables,
  cacert,
  aardvark-dns,
  podman,
}:
let
  runcStatic = runc.overrideAttrs (old: {
    postInstall = (old.postInstall or "") + ''
      mv -f "$out/bin/.runc-wrapped" "$out/bin/runc"
    '';
  });
in
(podman.override {
  inherit
    conmon
    catatonit
    crun
    gpgme
    aardvark-dns
    ;
  runc = runcStatic;
}).overrideAttrs
  (oldAttrs: rec {
    version = "5.8.9";
    src = fetchFromGitHub {
      owner = "podman-container-tools";
      repo = "podman";
      tag = "v${version}";
      hash = "sha256-nIWwG5QyIent0vJtEm8zDQLbqfTZmD4oKMbf2N5r2wA=";
    };

    propagatedBuildInputs = [ ];
    buildInputs = builtins.filter (
      dep: !lib.hasPrefix "systemd" (lib.getName dep)
    ) oldAttrs.propagatedBuildInputs;

    nativeInstallCheckInputs = [
      coreutils
    ];

    patches = [
      ./packaged-init.patch
      ./builtin-seccomp.patch

      ./registries-conf-dir.patch

      ./policy-json-env.patch
    ];

    postFixup = "";
    postInstall = ''
      cp -Lf --remove-destination ${oldAttrs.passthru.helpersBin}/bin/* "$out/libexec/podman/"
      mv "$out/bin/.podman-wrapped" "$out/bin/_podman"
      rm -f "$out/bin/podmansh"
      rm -rf "$out/lib/systemd" "$out/lib/tmpfiles.d" "$out/share/systemd"
      install -m755 ${lib.getBin nftables}/bin/nft "$out/libexec/podman/nft"
      install -m755 ${busybox}/bin/busybox "$out/libexec/podman/busybox"
      for tool in sh readlink mkdir sed cp; do
        ln -s busybox "$out/libexec/podman/$tool"
      done
      mkdir -p "$out/conf/certs"
      cp -a ${./bin}/. "$out/bin/"
      cp -r ${./conf}/. "$out/conf/"
      cp ${cacert}/etc/ssl/certs/ca-bundle.crt "$out/conf/ca-bundle.crt"
    '';

    installCheckPhase = ''
      runHook preInstallCheck
      export GOCACHE=$TMPDIR/go-cache
      export HOME=$TMPDIR/home
      mkdir -p "$HOME"
      go build -mod=vendor -tags containers_image_openpgp,seccomp -o "$out/bin/config-check" ${./tests/config-check.go}
      cp ${./tests/network_test.go} vendor/go.podman.io/common/libnetwork/netavark/standalone_test.go
      PODMAN_TEST_NETWORK_DIR=$out/conf/networks go test -mod=vendor -run '^TestStandaloneNetwork$' go.podman.io/common/libnetwork/netavark
      cp ${./tests/seccomp_test.go} libpod/standalone_seccomp_test.go
      CONTAINERS_CONF=$out/conf/containers.conf CONTAINERS_STORAGE_CONF=$out/conf/storage.conf PODMAN_DATA_DIR=$TMPDIR/data PODMAN_RUNTIME_DIR=$TMPDIR/runtime go test -mod=vendor -tags containers_image_openpgp,seccomp -run '^TestStandaloneSeccomp$' ./libpod
      bash ${./tests/package.sh} "$out"
      rm "$out/bin/config-check"
      runHook postInstallCheck
    '';
  })
