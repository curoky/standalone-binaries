# psql — the PostgreSQL interactive client, built as a fully-static musl binary.
#
# Only the `psql` client is shipped (the user only needs psql). The stock
# `pkgsStatic.postgresql` build fails here for two reasons, both fixed below:
#
#   1. postgresql's generic.nix switches the compiler from gcc to clang (to
#      enable `-flto`). In this repo's musl64-cross static set clang is broken:
#      it can't find `-lgcc_eh`, is missing `libunwind.a`, and has no usable
#      `lld` (`configure: error: C compiler cannot create executables`). gcc in
#      the same set works fine. generic.nix only keeps the incoming stdenv when
#      `cc.isClang` is already true, so we fake `isClang = true` to keep gcc.
#
#   2. gcc's `-flto` breaks postgres's partial-link (`ld -r`) step, so we drop
#      `-flto` from CFLAGS (keeping the section-GC flags).
#
# A fully-static gcc toolchain also cannot link shared objects, so we skip the
# server backend (charset-conversion `.so` modules) entirely and build only
# libpq's static archive plus psql. libpq's `all`/`all-lib` targets are patched
# to not require the `.so`.
{
  stdenv,
  postgresql,
}:
let
  # Keep gcc but make generic.nix believe it already got a clang stdenv, so it
  # does not swap in the (broken) clang toolchain.
  gccAsClang = stdenv // {
    cc = stdenv.cc // {
      isClang = true;
    };
  };
in
(postgresql.override {
  stdenv = gccAsClang;
  # JIT (`--with-llvm`) is on by default for a native build, but it needs a
  # working clang, which this musl-cross static set lacks (`clang not found`).
  # We only ship libpq + psql (no server backend), so JIT is irrelevant.
  jitSupport = false;
  # PL/Perl is a server-side extension we don't build; its configure step also
  # fails against the static (non-shared) perl ("libperl is not a shared
  # library"). PL/Python and PL/Tcl are likewise server-side and fail the same
  # way (no shared libpython under static musl). We only ship libpq + psql, so
  # disable all the procedural languages.
  perlSupport = false;
  pythonSupport = false;
  tclSupport = false;
  # libcurl support (OAuth device flow) is new in PostgreSQL 18 and on by
  # default, but the static curl link test fails here ("library 'curl' does not
  # provide curl_multi_init"). psql/libpq worked fine without it before 18, so
  # disable it.
  curlSupport = false;
  # GSSAPI (Kerberos) auth fails the static configure link test here
  # ("could not find function 'gss_store_cred_into'": the static libkrb5 archive
  # doesn't resolve). It is an optional psql auth method, so disable it to keep
  # the fully-static build linking.
  gssSupport = false;
}).overrideAttrs (old: {
  # Upstream marks the whole derivation broken for static hosts because the
  # server cannot load shared modules. This package builds only libpq's static
  # archive and psql, so that server limitation does not apply.
  meta = (old.meta or { }) // {
    broken = false;
  };

  # Ship one self-contained output. The stock split creates a cycle here
  # because the server and pg_config are intentionally not built.
  outputs = [ "out" ];
  outputChecks = { };

  env = (old.env or { }) // {
    CFLAGS = "-fdata-sections -ffunction-sections";
  };

  # The inherited postPatch substitutes split-output variables. Point them all
  # at the sole output, then make libpq build only its static archive.
  postPatch = ''
    export dev="$out" doc="$out" man="$out"
  ''
  + (old.postPatch or "")
  + ''
    substituteInPlace src/Makefile.shlib \
      --replace-fail "all-lib: all-shared-lib" "all-lib: all-static-lib" \
      --replace-fail "install-lib: install-lib-shared" "install-lib: install-lib-static"
    substituteInPlace src/interfaces/libpq/Makefile \
      --replace-fail "all: all-lib libpq-refs-stamp" "all: all-lib"
  '';

  preConfigure = (old.preConfigure or "") + ''
    configureFlagsArray+=(
      "--includedir=$out/include"
      "--mandir=$out/share/man"
      "--docdir=$out/share/doc/postgresql"
      "--libdir=$out/lib"
      "--libexecdir=$out/lib/libexec"
      "--localedir=$out/lib/share/locale"
    )
  '';

  buildPhase = ''
    runHook preBuild
    make -C src/interfaces/libpq all-lib -j$NIX_BUILD_CORES
    make -C src/bin/psql -j$NIX_BUILD_CORES
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    make -C src/interfaces/libpq install
    make -C src/bin/psql bindir="$out/bin" install
    runHook postInstall
  '';

  postInstall = "";
})
