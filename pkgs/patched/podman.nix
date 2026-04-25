{
  lib,
  stdenv,
  fetchFromGitHub,
  pkg-config,
  installShellFiles,
  buildGoModule,
  buildPackages,
  gpgme,
  gnupg,
  lvm2,
  btrfs-progs,
  libapparmor,
  libseccomp,
  libselinux,
  systemd,
  nixosTests,
  python3,
  makeBinaryWrapper,
  symlinkJoin,
  replaceVars,
  extraPackages ? [ ],
  crun,
  runc,
  conmon,
  extraRuntimes ? lib.optionals stdenv.hostPlatform.isLinux [ runc ], # e.g.: runc, gvisor, youki
  fuse-overlayfs,
  util-linuxMinimal,
  nftables,
  iptables,
  iproute2,
  catatonit,
  gvproxy,
  aardvark-dns,
  netavark,
  passt,
  vfkit,
  versionCheckHook,
  writableTmpDirAsHomeHook,
  coreutils,
  runtimeShell,
  podman,
}:
let
  minimalGnuPG = gnupg.override {
    enableMinimal = true;
    guiSupport = false;
  };

  gpgmeWithMinimalGnuPG =
    (gpgme.override {
      gnupg = minimalGnuPG;
    }).overrideAttrs
      (oldAttrs: {
        configureFlags = (oldAttrs.configureFlags or [ ]) ++ [
          "--disable-gpg-test"
        ];
        doCheck = false;
      });
in
podman.overrideAttrs (oldAttrs: rec {
  propagatedBuildInputs = [ ];
  buildInputs = lib.optionals stdenv.hostPlatform.isLinux [
    btrfs-progs
    gpgmeWithMinimalGnuPG
    libapparmor
    libseccomp
    libselinux
    lvm2
  ];

  patches = [
    (replaceVars ./podman/hardcode-paths.patch {
      bin_path = "/opt/mypodman/bin";
    })

    # we intentionally don't build and install the helper so we shouldn't display messages to users about it
    ./podman/rm-podman-mac-helper-msg.patch
  ];

  postFixup = "";

  passthru = {
    tests = lib.optionalAttrs stdenv.hostPlatform.isLinux {
      inherit (nixosTests) podman;
      # related modules
      inherit (nixosTests)
        podman-tls-ghostunnel
        ;
      oci-containers-podman = nixosTests.oci-containers.podman;
    };
    # do not add qemu to this wrapper, store paths get written to the podman vm config and break when GCed
    binPath = lib.makeBinPath (
      lib.optionals stdenv.hostPlatform.isLinux [
        fuse-overlayfs
        util-linuxMinimal
        iptables
        iproute2
        nftables
      ]
      ++ lib.optionals stdenv.hostPlatform.isDarwin [
        vfkit
      ]
      ++ extraPackages
    );

    helpersBin = symlinkJoin {
      name = "podman-helper-binary-wrapper";

      # this only works for some binaries, others may need to be added to `binPath` or in the modules
      paths = [
        gvproxy
      ]
      ++ lib.optionals stdenv.hostPlatform.isLinux [
        aardvark-dns
        # catatonit # added here for the pause image and also set in `containersConf` for `init_path`
        netavark
        passt
        # conmon
        # crun
      ]
      ++ extraRuntimes;
    };
  };

})
