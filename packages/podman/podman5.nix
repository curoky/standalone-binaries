{
  lib,
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
  # Upstream wraps static runc in a dynamic PATH launcher. Ship the real ELF.
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
  (oldAttrs: {
    # pkgsStatic propagates upstream build inputs. cgroupfs/file logging need no libsystemd.
    propagatedBuildInputs = [ ];
    buildInputs = builtins.filter (dep: lib.getName dep != "systemd") oldAttrs.propagatedBuildInputs;

    nativeInstallCheckInputs = [
      coreutils
    ];

    patches = [
      ./packaged-init.patch
      ./builtin-seccomp.patch

      # Keep registry drop-ins inside the package instead of scanning host paths.
      ./registries-conf-dir.patch

      # podman 5.x ignores CONTAINERS_POLICY_JSON; backport the podman 6.x env
      # override so the wrapper can resolve policy.json relative to the binary.
      ./policy-json-env.patch
    ];

    postFixup = "";
    postInstall = ''
      cp -Lf --remove-destination ${oldAttrs.passthru.helpersBin}/bin/* "$out/libexec/podman/"
      mv "$out/bin/.podman-wrapped" "$out/bin/_podman"
      rm -f "$out/bin/podmansh"
      rm -rf "$out/lib/systemd" "$out/lib/tmpfiles.d" "$out/share/systemd"
      # Complete tools for the fixed backend; no inherited host PATH.
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
