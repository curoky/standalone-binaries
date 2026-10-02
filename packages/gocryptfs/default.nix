# gocryptfs — static dependency and CGO discovery fixes.
#
# Why local:
# 1. Nixpkgs propagates libfido2 so runtime `fido2-*` commands reach PATH, but
#    its pcsclite documentation output fails to build under musl-static.
#    Gocryptfs does not link libfido2; it invokes those optional tools through
#    `os/exec`, so the standalone package may rely on the host PATH instead.
# 2. The OpenSSL CGO backend uses `pkg-config: libcrypto`, but the target wrapper
#    does not discover the static OpenSSL `.pc` file automatically in this cross
#    setup. Point `PKG_CONFIG_PATH` at the target development output.
#
# Remove each workaround when stock dependency propagation and CGO discovery
# work under musl-static.
{
  lib,
  gocryptfs,
  openssl,
}:

gocryptfs.overrideAttrs (_: {
  propagatedBuildInputs = [ ];
  PKG_CONFIG_PATH = "${lib.getDev openssl}/lib/pkgconfig";
})
