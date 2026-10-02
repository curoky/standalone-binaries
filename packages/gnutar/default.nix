# gnutar — static xattr symbol collision.
#
# Why local:
# 1. Gnutar's bundled gnulib supplies fallback `getxattrat`, `setxattrat` and
#    `listxattrat` symbols.
# 2. Current static libacl supplies the same symbols, so the final tar link fails
#    with multiple definitions under GCC's `-fno-common` behavior.
# 3. Both implementations are equivalent fallbacks; pass
#    `--allow-multiple-definition` only to the final automake link rather than
#    disabling ACL/xattr support or contaminating configure probes.
#
# Remove the flag when stock gnutar and libacl no longer export both copies.
{
  gnutar,
}:

gnutar.overrideAttrs (old: {
  # Keep the flag out of configure's compiler probe; it applies only to the
  # final automake link.
  makeFlags = (old.makeFlags or [ ]) ++ [ "LDFLAGS=-Wl,--allow-multiple-definition" ];
})
