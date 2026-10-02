# psql for Linux — client-only musl-static PostgreSQL build.
#
# Why local:
# 1. Nixpkgs switches PostgreSQL to clang for LTO. This musl cross clang cannot
#    find its unwind/runtime libraries, while GCC works; preserve the GCC stdenv
#    and remove `-flto`, which also breaks PostgreSQL's `ld -r` partial link.
# 2. The static toolchain cannot build the server's loadable charset and
#    procedural-language modules. Disable JIT and PL/Perl/Python/Tcl, and build
#    only libpq's static archive plus psql.
# 3. PostgreSQL 18 enables curl OAuth support, but its static configure probe
#    cannot resolve curl's private closure. Disable that optional client path.
# 4. GSSAPI's static configure probe cannot resolve `gss_store_cred_into` from
#    the Kerberos archives. Disable that optional authentication path.
# 5. Stock metadata marks all static PostgreSQL broken and splits outputs around
#    the server. Clear that guard for this client-only build and publish one
#    self-contained output.
#
# Regress compiler and optional-feature workarounds independently; the psql-only
# product boundary remains.
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
}).overrideAttrs
  (old: {
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
