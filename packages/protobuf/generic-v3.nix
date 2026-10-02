# Legacy Protobuf v3 build helper.
#
# 1. Cross compilation cannot execute the target protoc needed while generating
#    target sources, so instantiate the same source once for the build platform
#    and pass that native compiler through `--with-protoc`.
# 2. Replace the old bundled gmock/gtest trees with the selected nixpkgs test
#    source so this legacy release can compile and run checks with the current
#    toolchain.
# 3. Keep static-library generation enabled and link the target zlib; this helper
#    is Linux-only and is not itself a published package entry point.
{
  lib,
  stdenv,
  fetchFromGitHub,
  autoreconfHook,
  zlib,
  gtest,
  buildPackages,
  version,
  sha256,
  ...
}:

let
  mkProtobufDerivation =
    buildProtobuf: stdenv:
    stdenv.mkDerivation {
      pname = "protobuf";
      inherit version;

      src = fetchFromGitHub {
        owner = "protocolbuffers";
        repo = "protobuf";
        rev = "v${version}";
        inherit sha256;
      };

      postPatch = ''
        rm -rf gmock
        cp -r ${gtest.src}/googlemock gmock
        cp -r ${gtest.src}/googletest googletest
        chmod -R a+w gmock
        chmod -R a+w googletest
        ln -s ../googletest gmock/gtest
      '';

      nativeBuildInputs = [
        autoreconfHook
        buildPackages.which
        buildPackages.stdenv.cc
        buildProtobuf
      ];

      buildInputs = [ zlib ];
      configureFlags = lib.optional (buildProtobuf != null) "--with-protoc=${buildProtobuf}/bin/protoc";

      enableParallelBuilding = true;

      doCheck = true;

      dontDisableStatic = true;

      meta = {
        description = "Google's data interchange format";
        longDescription = ''
          Protocol Buffers are a way of encoding structured data in an efficient
                  yet extensible format. Google uses Protocol Buffers for almost all of
                  its internal RPC protocols and file formats.
        '';
        homepage = "https://developers.google.com/protocol-buffers/";
        license = lib.licenses.bsd3;
        mainProgram = "protoc";
        platforms = lib.platforms.linux;
      };
    };
in
mkProtobufDerivation (
  if (stdenv.buildPlatform != stdenv.hostPlatform) then
    (mkProtobufDerivation null buildPackages.stdenv)
  else
    null
) stdenv
