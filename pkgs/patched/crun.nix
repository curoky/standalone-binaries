{
  stdenv,
  lib,
  fetchFromGitHub,
  autoreconfHook,
  go-md2man,
  pkg-config,
  libcap,
  libseccomp,
  python3,
  systemd,
  yajl,
  argp-standalone,
  nixosTests,
  criu,
  crun,
}:

(crun.override {
  withLibkrun = false;
  withLibkrunSEV = false;
}).overrideAttrs
  (oldAttrs: rec {
    propagatedBuildInputs = [ ];
    buildInputs = [
      # criu
      libcap
      libseccomp
      # gperf
      yajl
      argp-standalone
    ];
    env = {
      NIX_LDFLAGS = "";
    };
    configureFlags = [
      "--disable-systemd"
      "--enable-embedded-yajl"
      "--without-python-bindings"
    ];

    doCheck = false;
  })
