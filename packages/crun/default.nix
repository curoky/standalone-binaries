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
  json_c,
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
      json_c
      argp-standalone
    ];
    env = {
      NIX_LDFLAGS = "";
      CFLAGS = "-static";
      LDFLAGS = "-static";
      CRUN_LDFLAGS = "-all-static";
    };
    configureFlags = [
      "--enable-static"
      "--disable-systemd"
      "--without-python-bindings"
    ];

    doCheck = false;
  })
