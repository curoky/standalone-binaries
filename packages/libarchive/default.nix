# libarchive — musl-static bsdtar/bsdcpio/bsdunzip with no Nix store paths.
#
# The stock static CLIs embed Nix store paths: the OpenSSL output's default
# dirs and libxml2's catalog path. Fix the root causes:
#   - Rebuild OpenSSL (`portableOpenSSL`) with OPENSSLDIR/ENGINESDIR/MODULESDIR
#     pointed at standard system paths instead of the Nix store output.
#   - `xarSupport = false` to drop XAR and its libxml2 catalog dependency.
# ZIP AES support is kept. `postFixup` fails the build if any `/nix/store`
# string survives in the produced binaries.
{
  libarchive,
  openssl,
}:

let
  portableOpenSSL = openssl.overrideAttrs (oldAttrs: {
    postPatch = oldAttrs.postPatch + ''
      substituteInPlace Configurations/unix-Makefile.tmpl \
        --replace-fail 'OPENSSLDIR="\"$(OPENSSLDIR)\""' 'OPENSSLDIR="\"/etc/ssl\""' \
        --replace-fail 'ENGINESDIR="\"$(ENGINESDIR)\""' 'ENGINESDIR="\"/usr/lib/engines\""' \
        --replace-fail 'MODULESDIR="\"$(MODULESDIR)\""' 'MODULESDIR="\"/usr/lib/ossl-modules\""'
    '';
  });
in
(libarchive.override {
  openssl = portableOpenSSL;
  xarSupport = false;
}).overrideAttrs
  (oldAttrs: {
    postFixup = (oldAttrs.postFixup or "") + ''
      for binary in "$out"/bin/*; do
        if grep -aqF /nix/store "$binary"; then
          echo "$binary contains a Nix store path" >&2
          exit 1
        fi
      done
    '';
  })
