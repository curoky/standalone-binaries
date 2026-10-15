# crun — reduced musl-static feature set.
#
# Why local:
# 1. libkrun and systemd support pull in elfutils/systemd dependencies marked
#    unsupported on static hosts, so stock evaluation cannot complete.
# 2. Python bindings require a loadable extension and are incompatible with the
#    fully static target.
# 3. The rootless, namespace and cgroup tests require kernel facilities the
#    cross-build sandbox cannot exercise; the suite currently fails in bulk.
# 4. The remaining runtime uses libcap, libseccomp, json-c and argp and is linked
#    with crun's all-static mode.
#
# Re-enable each feature and the checks independently when its static path is
# supported.
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
      libcap
      libseccomp
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
