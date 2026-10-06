# buildah — portable musl-static Go build.
#
# Stock behavior and failure:
# 1. Stock buildah-unwrapped uses GPGME, which pulls in full GnuPG. Full GnuPG
#    reaches OpenLDAP, whose musl-static build cannot locate Cyrus SASL and
#    aborts before Buildah can compile. Select the supported pure-Go OpenPGP
#    backend instead, as the repository's Podman builds already do.
#
# Remove this override when stock pkgsStatic.buildah-unwrapped builds with the
# pure-Go OpenPGP backend or a static-compatible GPGME dependency closure.
{
  lib,
  buildah-unwrapped,
}:
buildah-unwrapped.overrideAttrs (oldAttrs: {
  propagatedBuildInputs = builtins.filter (
    dep: lib.getName dep != "gpgme"
  ) oldAttrs.propagatedBuildInputs;
  preBuild = (oldAttrs.preBuild or "") + ''
    export EXTRA_BUILD_TAGS=containers_image_openpgp
  '';
})
