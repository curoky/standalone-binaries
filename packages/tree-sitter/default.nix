# tree-sitter — static install-target fix.
#
# Why local:
# 1. The static Makefile correctly omits the shared-library build target.
# 2. Nixpkgs tries to remove shared install commands with a sed range beginning
#    at `install:`, but that range terminates on the same non-indented line and
#    removes nothing.
# 3. `make install` then fails because `libtree-sitter.so` was never produced.
#    Delete the three shared install/symlink commands explicitly on static hosts.
#
# Remove this override when stock static tree-sitter no longer installs `.so`.
{
  lib,
  stdenv,
  tree-sitter,
}:

tree-sitter.overrideAttrs (old: {
  postPatch =
    (old.postPatch or "")
    + lib.optionalString stdenv.hostPlatform.isStatic ''
      sed -i \
        -e '/install -m755 libtree-sitter\.$(SOEXT)/d' \
        -e '/ln -sf libtree-sitter\.$(SOEXTVER)/d' \
        -e '/ln -sf libtree-sitter\.$(SOEXTVER_MAJOR)/d' \
        ./Makefile
    '';
})
