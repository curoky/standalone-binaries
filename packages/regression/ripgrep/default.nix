# Ripgrep — provide the system Rust Jemalloc library.
#
# Nixpkgs' Cargo setup hook forbids implicit vendored libraries and sets a
# sentinel JEMALLOC_OVERRIDE. Ripgrep 15.2 uses tikv-jemalloc-sys, but its stock
# derivation omits the corresponding system library, so build.rs fails on the
# nonexistent sentinel path. Use nixpkgs' Rust-prefixed Jemalloc package and
# its setup hook; keep Ripgrep's PCRE2 feature and upstream checks.
# Remove this override when stock Ripgrep declares rust-jemalloc-sys itself.
{
  ripgrep,
  rust-jemalloc-sys,
}:
ripgrep.overrideAttrs (old: {
  buildInputs = old.buildInputs ++ [ rust-jemalloc-sys ];
})
