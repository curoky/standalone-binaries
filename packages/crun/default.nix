# crun — fully-static musl build for podman's container runtime.
#
# Stock features are not recoverable here: enabling them pulls in `elfutils`,
# whose `meta.badPlatforms` includes `isStatic`, so the musl-static set is
# rejected at eval time. Feature disabling (libkrun/systemd/python bindings)
# must stay.
#
# `doCheck = false` is likewise required: restoring the checks runs 348 tests,
# 37 of which fail (rootless/namespace cases the musl-static sandbox cannot
# exercise).
#
# crun 1.29 (upstream PR #2088) swapped YAJL for json-c, so `buildInputs` uses
# `json_c` (not `yajl`) and the now-removed `--enable-embedded-yajl` flag is
# gone.
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
