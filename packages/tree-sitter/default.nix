{
  lib,
  stdenv,
  tree-sitter,
}:

# On static hosts, tree-sitter's Makefile still builds only the static archive
# (the `.so` target is dropped), but the stock postPatch fails to strip the
# shared-object lines from the `install:` target: its sed range
# `/^install:/,/^[^[:space:]]/` terminates on the `install:` line itself (which
# starts with a non-whitespace char), so nothing is deleted and `make install`
# aborts with "cannot stat 'libtree-sitter.so'". Remove those three shared-lib
# install/symlink lines directly. Consumed by rizin via .override.
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
