# aardvark-dns — musl close_range compatibility.
#
# Why local:
# 1. Upstream calls the libc `close_range` wrapper unconditionally.
# 2. Musl exposes the syscall number but not that wrapper, so the Rust build
#    fails when resolving `libc::close_range`.
# 3. The patch calls the raw Linux syscall without changing vendored crates, so
#    the upstream cargo vendor hash remains valid.
#
# Remove the patch when upstream uses a musl-compatible close_range path.
{
  aardvark-dns,
}:

aardvark-dns.overrideAttrs (oldAttrs: {
  patches = (oldAttrs.patches or [ ]) ++ [
    ./musl-close-range-syscall.patch
  ];
})
