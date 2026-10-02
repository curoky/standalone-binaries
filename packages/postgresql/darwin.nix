# psql for macOS — static libpq client with system resource paths.
#
# Why local:
# 1. `pkgsStatic.libpq` provides the portable client libraries but does not
#    install psql. Build and install that client explicitly without the server.
# 2. Static OpenSSL compiles its configuration, engine, module and certificate
#    paths under the Nix output. Patch those defaults to macOS/system paths
#    before linking them into psql.
# 3. Keep every Nix dependency static; only Apple system libraries may remain
#    as Mach-O load commands.
#
# Remove this override when stock static libpq ships psql without embedded Nix
# resource paths.
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
}).overrideAttrs
  (old: {
    configureFlags = (old.configureFlags or [ ]) ++ [ "--bindir=/usr/local/bin" ];

    postBuild = (old.postBuild or "") + ''
      make -C src/bin/psql -j$NIX_BUILD_CORES
    '';

    postInstall =
      (old.postInstall or "")
      + "\n"
      + ''
        make -C src/bin/psql bindir="$out/bin" install
      '';
  })
