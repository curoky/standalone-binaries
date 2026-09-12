# psql for macOS, built on nixpkgs' static libpq client package so every Nix
# dependency is linked from a static archive and only Apple system libraries
# remain dynamic.
{
  libpq,
  openssl,
}:
let
  portableOpenSSL = openssl.overrideAttrs (old: {
    postPatch = (old.postPatch or "") + ''
      substituteInPlace Configurations/unix-Makefile.tmpl \
        --replace-fail 'OPENSSLDIR="\"$(OPENSSLDIR)\""' 'OPENSSLDIR="\"/etc/ssl\""' \
        --replace-fail 'ENGINESDIR="\"$(ENGINESDIR)\""' 'ENGINESDIR="\"/usr/lib/engines\""' \
        --replace-fail 'MODULESDIR="\"$(MODULESDIR)\""' 'MODULESDIR="\"/usr/lib/ossl-modules\""'
      substituteInPlace include/internal/common.h \
        --replace-fail "/nix/var/nix/profiles/default/etc/ssl/certs/ca-bundle.crt" "/etc/ssl/cert.pem"
    '';
  });
in
(libpq.override {
  openssl = portableOpenSSL;
}).overrideAttrs (old: {
  configureFlags = (old.configureFlags or [ ]) ++ [ "--bindir=/usr/local/bin" ];

  postBuild = (old.postBuild or "") + ''
    make -C src/bin/psql -j$NIX_BUILD_CORES
  '';

  postInstall = (old.postInstall or "") + "\n" + ''
    make -C src/bin/psql bindir="$out/bin" install
  '';
})
