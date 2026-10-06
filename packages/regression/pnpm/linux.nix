# pnpm — cross-static host compiler isolation.
#
# Stock pnpm 12.9.0 is already the Rust-native implementation and builds the
# shipped binary for musl. One dependency, libsql-sqlite3-parser, also compiles
# a helper that runs on the glibc build platform. Its build.rs selects HOST_CC
# correctly, but cc 1.2.60 still infers -static from the target crate's
# CARGO_CFG_TARGET_FEATURE=crt-static and then cannot find a static glibc libc.
#
# Keep the stock source and package definition. Disable cc's inferred static
# flag only for that host helper, then refresh the vendored Cargo checksum.
#
# Remove this override when stock pkgsStatic.pnpm separates host and target
# linker flags for the libsql-sqlite3-parser helper.
{ pnpm }:

pnpm.overrideAttrs (oldAttrs: {
  postPatch = (oldAttrs.postPatch or "") + ''
    libsqlParser="$cargoDepsCopy/source-registry-0/libsql-sqlite3-parser-0.13.0"
    substituteInPlace "$libsqlParser/build.rs" \
      --replace-fail \
        'Build::new()' \
        'Build::new().static_flag(false)'
    buildRsHash="$(sha256sum "$libsqlParser/build.rs" | cut -d ' ' -f 1)"
    sed -i -E \
      "s#(\"build.rs\":\")[0-9a-f]{64}\"#\1$buildRsHash\"#" \
      "$libsqlParser/.cargo-checksum.json"
  '';
})
