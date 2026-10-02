# krb5 for macOS — static archive linkage fixes.
#
# Why local:
# 1. Configure enables `USE_CCAPI_MACOS`, compiles `cc_api_macos.c` and selects
#    `API:` as the default credential cache. That archive member calls
#    `cc_initialize`, which is available only from the Kerberos framework and is
#    not linked into static libkrb5 consumers; final links fail with undefined
#    `_cc_initialize`. Disable CCAPI and retain the portable FILE cache backend.
# 2. `mit_des_zeroblock` is defined in `f_aead.o`, but no other referenced symbol
#    causes macOS ld to extract that member from `libk5crypto.a`. When
#    `d3_aead.o` is selected, its reference remains undefined. Move the identical
#    zero constant into the referencing translation unit so the archive link can
#    resolve it.
# 3. Both changes affect only static linkage. The resulting binaries may retain
#    Apple system libraries, but no Nix dylib or framework path.
#
# Remove each fix when stock static krb5 links its consumers without the
# corresponding undefined symbol.
{ krb5 }:

krb5.overrideAttrs (old: {
  patches = (old.patches or [ ]) ++ [ ./static-darwin-des-zeroblock.patch ];

  postPatch = (old.postPatch or "") + ''
    substituteInPlace configure \
      --replace-fail 'macos_defccname=API:' 'macos_defccname=' \
      --replace-fail 'printf "%s\n" "#define USE_CCAPI_MACOS 1" >>confdefs.h' ':'
  '';
})
