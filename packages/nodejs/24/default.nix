# Node.js 24 — versioned musl-static runtime.
#
# Why local:
# 1. Gyp imports ctypes, which the static target Python cannot load. Configure
#    with build-platform Python instead.
# 2. Ada's tests expect fuzzer executables that its static build does not
#    produce, so disable only that dependency's checks.
# 3. Static stdenv appends autotools flags that Node's Python configure script
#    rejects; remove `--enable-static` and `--disable-shared` from that input.
# 4. System Brotli is split into archives whose one-pass link order leaves
#    common symbols unresolved. Use Node's matched bundled copy.
# 5. The nixpkgs simdutf selected for Node 24 lacks API used by this source. Use
#    Node's bundled copy rather than linking mismatched headers/libraries.
# 6. Node's checks build `.node` shared addons with a non-PIC static CRT and fail
#    on `__TMC_END__` relocations, so checks remain disabled.
#
# The Node 24 output is a product version. Regress each build workaround
# independently when stock `pkgsStatic.nodejs_24` supports it.
{
  lib,
  pkgsStatic,
  python3,
}:

let
  pkgsStaticNode = pkgsStatic.extend (
    _: prev: {
      ada = prev.ada.overrideAttrs { doCheck = false; };
    }
  );

  patchedNode = (pkgsStaticNode.nodejs-slim_24.override { python3 = python3; }).overrideAttrs (old: {
    configureFlags = builtins.filter (
      f:
      f != "--enable-static"
      && f != "--disable-shared"
      # Make node use its own bundled copies of brotli and simdutf instead of
      # the system static libraries:
      #   - brotli: the system static build ships split archives
      #     (libbrotli{common,enc,dec}.a) which the single-pass musl GNU ld
      #     fails to link in the right order, leaving common symbols (e.g.
      #     `_kBrotliPrefixCodeRanges`) undefined.
      #   - simdutf: nixpkgs pins simdutf 6.5.0 for node < 25, but node 24's
      #     string_bytes.cc references newer simdutf API
      #     (`simdutf::base64_to_binary_safe`) absent from 6.5.0, causing
      #     undefined references at link time.
      && f != "--shared-brotli"
      && f != "--shared-simdutf"
      && !(lib.hasPrefix "--shared-brotli-libpath=" f)
      && !(lib.hasPrefix "--shared-simdutf-libpath=" f)
    ) old.configureFlags;
    buildInputs = builtins.filter (
      p: !(lib.hasInfix "brotli" (p.name or "")) && !(lib.hasInfix "simdutf" (p.name or ""))
    ) (old.buildInputs or [ ]);
    # The check phase builds native test addons (test/js-native-api/*,
    # build-{js-native,node}-api-tests) which link `.node` shared objects.
    # Under the fully static (musl) gcc toolchain that fails with `relocation
    # R_X86_64_32 against hidden symbol __TMC_END__ can not be used when making
    # a shared object` (static CRT crtbeginT.o is not PIC). These test addons
    # are irrelevant to the node binary, so skip the checks.
    doCheck = false;
  });
in
patchedNode.overrideAttrs (_: {
  pname = "nodejs-slim24";
  __intentionallyOverridingVersion = true;
})
