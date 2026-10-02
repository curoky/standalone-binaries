{
  lib,
  systems,
  channels,
  pins,
}:
system:
let
  isDarwin = lib.hasSuffix "darwin" system;
  isUpstreamOnly = system == "aarch64-linux";

  # Linux uses a musl cross-static set so the target stays fully static while
  # build tools can reuse the native glibc Rust and LLVM toolchains.
  mkEnv =
    input:
    let
      base = import input { inherit system; };
      rawLinuxStatic =
        if system == "aarch64-linux" then
          base.pkgsCross.aarch64-multiplatform-musl.pkgsStatic
        else
          base.pkgsCross.musl64.pkgsStatic;
      rawPkgsStatic = if isDarwin then base.pkgsStatic else rawLinuxStatic;
      # aarch64-linux is an upstream-only, best-effort platform. Keep its
      # package set stock instead of carrying local producer overrides.
      pkgsStatic =
        if isUpstreamOnly then
          rawPkgsStatic
        else
          rawPkgsStatic.extend (
            import ../packages/static-build-tools.nix {
              inherit (base) lib;
              nativePkgs = base;
            }
          );
    in
    {
      pkgs = base;
      inherit pkgsStatic rawPkgsStatic;
    };

  channelEnvs = lib.mapAttrs (_: mkEnv) channels;
  pinEnvs = lib.mapAttrs (_: mkEnv) pins;
  envs = channelEnvs // pinEnvs;

  pkgs = envs.unstable.pkgs;
  pkgsStatic = envs.unstable.pkgsStatic;
  artifactTool = pkgs.callPackage ../cmd/artifact/package.nix { };
  validateNativeBuildInputs = import ./validate-native-build-inputs.nix { inherit lib; };
  makeManifestPackages = import ./make-manifest-packages.nix {
    inherit lib envs;
    allSystems = systems;
  };
  makeArtifacts = import ./make-artifacts.nix {
    inherit pkgs artifactTool validateNativeBuildInputs;
  };
  makeProbeArtifacts = import ./make-artifacts.nix {
    inherit pkgs artifactTool;
    validateNativeBuildInputs = drv: drv;
  };

  upstreamPackages = makeManifestPackages system (import ../packages/upstream.nix);
  localPackages =
    if isUpstreamOnly then
      { }
    else
      import ../packages {
        inherit system pkgs pkgsStatic;
        masterPkgsStatic = envs.master.pkgsStatic;
        s6PkgsStatic = envs."s6-pin".pkgsStatic;
      };
  sourcePackages = upstreamPackages // localPackages;

  artifacts = lib.mapAttrs makeArtifacts sourcePackages;
  standalonePackages = artifacts;
  tarballPackages = lib.mapAttrs (_: artifact: artifact.archive) artifacts;

  mkProbeChannel =
    env:
    lib.genAttrs (builtins.attrNames env.rawPkgsStatic) (
      name: makeProbeArtifacts name env.rawPkgsStatic.${name}
    );
  probe = lib.mapAttrs' (
    name: env: lib.nameValuePair (lib.replaceStrings [ "." ] [ "" ] name) (mkProbeChannel env)
  ) channelEnvs;

  isSlowLLVM =
    name:
    lib.hasPrefix "clang-tools-" name
    || lib.hasPrefix "lld_" name
    || (lib.match "clang[0-9]+" name) != null;
  mkAll =
    label: predicate:
    pkgs.linkFarm label (
      lib.mapAttrsToList (name: path: { inherit name path; }) (
        lib.filterAttrs (name: _: predicate name) standalonePackages
      )
    );
in
{
  packages = standalonePackages // {
    all = mkAll "all-standalone-tools" (_: true);
    all-fast = mkAll "all-standalone-tools-fast" (name: !isSlowLLVM name);
  };
  tarballs = tarballPackages;
  cacheRoots = lib.mapAttrs (name: artifact: {
    out = artifact.outPath;
    archive = artifact.archive.outPath;
    sources = [ sourcePackages.${name}.outPath ];
  }) artifacts;
  inherit probe;
  sources = sourcePackages;
}
