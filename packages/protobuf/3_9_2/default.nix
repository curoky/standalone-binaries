# Protobuf 3.9.2 — exact legacy musl-static output.
#
# Why local:
# 1. This exact version is part of the published product set, but current
#    nixpkgs channels no longer expose it as a usable static package.
# 2. Channels old enough to contain 3.9.2 do not provide a working build through
#    the repository's current musl cross-static pipeline, so a manifest pin
#    cannot produce the required output.
# 3. Build the pinned source with the local v3 derivation, which supplies a
#    native protoc for cross builds and keeps the target library static.
#
# Replace this file only when a supported channel provides the same version and
# it passes the full standalone portability gate.
{ callPackage }:
callPackage ../generic-v3.nix {
  version = "3.9.2";
  sha256 = "sha256-1mLSNLyRspTqoaTFylGCc2JaEQOMR1WAL7ffwJPqHyA=";
}
