{
  description = "Standalone, portable prebuilt tool binaries built with Nix";

  inputs = {
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    # Pinned unstable revision for the s6 stack (execline / s6 / s6-linux-init /
    # s6-rc / s6-dns / s6-linux-utils / s6-networking / s6-portable-utils /
    # skalibs). A later unstable bump broke these builds, so they stay on the
    # last revision verified to build+portable (recorded in the regression
    # docs). Only the s6 stack uses this env; everything else tracks unstable.
    nixpkgs-s6-2026-08-23.url = "github:NixOS/nixpkgs/56c02bc00adcf003215cc4bd996d6efaf4cff188";
    nixpkgs-2605.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixpkgs-2511.url = "github:NixOS/nixpkgs/nixos-25.11";
    nixpkgs-2505.url = "github:NixOS/nixpkgs/nixos-25.05";
    nixpkgs-2411.url = "github:NixOS/nixpkgs/nixos-24.11";
    nixpkgs-2405.url = "github:NixOS/nixpkgs/nixos-24.05";
  };

  outputs =
    inputs:
    let
      lib = inputs.nixpkgs-unstable.lib;

      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];

      # Build the per-system package set.
      perSystem =
        system:
        let
          isDarwin = lib.hasSuffix "darwin" system;

          # One env per pinned nixpkgs input, exposing both regular and static
          # package sets. The manifest selects which env + variant to use.
          #
          # On Linux, `pkgsStatic` is a musl *cross* set
          # (pkgsCross.<arch>.pkgsStatic: build = glibc, host == target =
          # musl-static) rather than the native-static set (build == host ==
          # target == musl). Build and host share the same arch, so
          # `buildPlatform.canExecute hostPlatform` stays true and checkPhases
          # are not disabled. The reason for cross: packages that link Rust deps
          # (e.g. node 26's temporal_capi) otherwise rebuild the entire musl
          # LLVM + rustc toolchain from source; the cross set takes rust's
          # `fastCross` path, reusing the cached glibc rustc/LLVM instead. The
          # cross attribute is arch-specific: `musl64` for x86_64,
          # `aarch64-multiplatform-musl` for aarch64. On Darwin the native
          # pkgsStatic is kept (pkgsCross.* there means cross-to-Linux).
          mkEnv =
            input:
            let
              base = import input { inherit system; };
              linuxStatic =
                if system == "aarch64-linux" then
                  base.pkgsCross.aarch64-multiplatform-musl.pkgsStatic
                else
                  base.pkgsCross.musl64.pkgsStatic;
            in
            {
              pkgs = base;
              pkgsStatic = if isDarwin then base.pkgsStatic else linuxStatic;
            };
          envs = {
            "unstable" = mkEnv inputs.nixpkgs-unstable;
            "s6-pin" = mkEnv inputs.nixpkgs-s6-2026-08-23;
            "26.05" = mkEnv inputs.nixpkgs-2605;
            "25.11" = mkEnv inputs.nixpkgs-2511;
            "25.05" = mkEnv inputs.nixpkgs-2505;
            "24.11" = mkEnv inputs.nixpkgs-2411;
            "24.05" = mkEnv inputs.nixpkgs-2405;
          };

          pkgs = envs.unstable.pkgs;
          pkgsStatic = envs.unstable.pkgsStatic;

          # --- helpers -----------------------------------------------------
          artifactTool =
            pkgs.runCommand "standalone-artifact-tool"
              {
                nativeBuildInputs = [ pkgs.buildPackages.go ];
              }
              ''
                cp -R ${./cmd/artifact} source
                chmod -R u+w source
                cd source
                export CGO_ENABLED=0
                export GO111MODULE=off
                export GOCACHE=$TMPDIR/go-cache
                mkdir -p "$out/bin"
                go build -trimpath -ldflags="-s -w" -o "$out/bin/artifact"
              '';
          makeManifestPackages = import ./lib/make-manifest-packages.nix {
            inherit lib envs;
            allSystems = systems;
          };
          makeArtifacts = import ./lib/make-artifacts.nix {
            inherit pkgs artifactTool;
          };

          # --- upstream packages (manifest-driven) -------------------------
          manifest = import ./manifests/default.nix;
          upstreamPackages = makeManifestPackages system manifest;

          # --- probe (manifest/patch-free upstream exploration) ------------
          # `nix build .#probe.<channel>.<pkg>` builds a raw upstream nixpkgs
          # package straight from a channel's pkgsStatic and runs it through the
          # normal artifact pipeline, bypassing both the manifest and the local
          # packages/ patches. Use it to check whether a package builds
          # unpatched on a given channel. <channel> is a channel key below and
          # <pkg> is any nixpkgs attr name.
          probeChannels = {
            unstable = envs.unstable;
            "2605" = envs."26.05";
            "2511" = envs."25.11";
            "2505" = envs."25.05";
            "2411" = envs."24.11";
            "2405" = envs."24.05";
          };
          mkProbeChannel =
            env:
            # Lazily map every top-level attr name to its artifact build.
            # attrNames only forces the top-level keys (cheap, does not build
            # packages); the artifact derivation is only realised when a
            # concrete `probe.<channel>.<pkg>` attr is accessed. Non-package or
            # unresolvable attrs simply fail when built, which is acceptable for
            # an exploration entrypoint.
            lib.genAttrs (builtins.attrNames env.pkgsStatic) (name: makeArtifacts name env.pkgsStatic.${name});
          probe = lib.mapAttrs (_: mkProbeChannel) probeChannels;

          # --- local packages (patched / wrapped / pinned) -----------------
          localPackages = import ./packages/local.nix {
            inherit pkgs pkgsStatic;
            # The s6 stack's local packages (execline / s6 / s6-linux-init /
            # s6-rc) build against this pinned static set instead of unstable;
            # see the nixpkgs-s6 input comment.
            s6PkgsStatic = envs."s6-pin".pkgsStatic;
          };

          allPackages =
            upstreamPackages
            // localPackages.common
            // lib.optionalAttrs isDarwin localPackages.darwin
            // lib.optionalAttrs (!isDarwin) localPackages.linux;

          artifacts = lib.mapAttrs makeArtifacts allPackages;
          standalonePackages = artifacts;
          tarballPackages = lib.mapAttrs (_: artifact: artifact.archive) artifacts;

          # Slow-to-build LLVM toolchain packages (clang-tools / clang / lld).
          # Excluded from `all-fast` so local `nix build .#all-fast` is quick.
          # CI still builds these via the dedicated build-llvm-tools workflow.
          isSlowLLVM =
            name:
            lib.hasPrefix "clang-tools-" name
            || lib.hasPrefix "lld_" name
            || (lib.match "clang[0-9]+" name) != null;

          mkAll =
            label: pred:
            pkgs.linkFarm label (
              lib.mapAttrsToList (name: path: { inherit name path; }) (
                lib.filterAttrs (name: _: pred name) standalonePackages
              )
            );
        in
        {
          packages = standalonePackages // {
            # Convenience aggregate of all standalone packages.
            all = mkAll "all-standalone-tools" (_: true);

            # Same as `all` but skips slow LLVM toolchain packages; handy for
            # quick local verification: `nix build .#all-fast`.
            all-fast = mkAll "all-standalone-tools-fast" (name: !isSlowLLVM name);
          };
          tarballs = tarballPackages;
          cacheRoots = lib.mapAttrs (name: artifact: {
            out = artifact.outPath;
            archive = artifact.archive.outPath;
            sources = [ allPackages.${name}.outPath ];
          }) artifacts;
          probe = probe;
          # Pre-artifact upstream/local derivations (the `--source` inputs to
          # make-artifacts), keyed by package name. Standalone outputs relativize
          # their contents and drop all store references, so the source closure
          # is absent from the standalone closure. Exposing it lets CI push the
          # source closure to the cache so rebuilds substitute upstream deps
          # instead of rebuilding from source.
          sources = allPackages;
        };
    in
    let
      perSystemOutputs = lib.genAttrs systems perSystem;
    in
    {
      packages = lib.mapAttrs (_: o: o.packages) perSystemOutputs;
      tarballs = lib.mapAttrs (_: o: o.tarballs) perSystemOutputs;
      probe = lib.mapAttrs (_: o: o.probe) perSystemOutputs;
      sources = lib.mapAttrs (_: o: o.sources) perSystemOutputs;
      cacheRoots = lib.mapAttrs (_: o: o.cacheRoots) perSystemOutputs;
    };
}
