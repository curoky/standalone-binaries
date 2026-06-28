# make-manifest-packages.nix
#
# Build a set of upstream nixpkgs packages from a declarative manifest for a
# given system.
#
# Manifest schema (see manifests/default.nix for the full reference):
#   <pkg> = {
#     platforms = [ "x86_64-linux" "aarch64-darwin" ];  # omitted => allSystems
#     version  = "unstable";   # which nixpkgs env (default "unstable")
#     isStatic = true;         # pkgsStatic (true, default) or pkgs (false)
#     output   = [ "out" ];    # outputs to expose (default [ "out" ])
#     alias    = "name";       # rename the exported attribute
#     bundle   = false;        # nix bundle into a single file (Linux only)
#     "<system>" = { ... };    # per-platform override of the fields above
#   };
#
# The effective config for `system` is the package-level shared config merged
# with the matching platform key (platform wins). Packages whose `platforms`
# list does not contain `system` are skipped.
#
# `bundle = true` routes a package through `makeBundle` (nix bundle, for tools
# that cannot be statically compiled). Bundle packages always use regular
# `pkgs` (never `pkgsStatic`) and their result is already a finished, self
# contained payload, so it must not be re-processed by the standalone step.
{
  lib,
  envs,
  allSystems,
  makeBundle,
}:
system: manifest:
let
  # Reserved keys are structural, not part of the per-platform config.
  reserved = [ "platforms" ] ++ allSystems;
in
lib.concatMapAttrs (
  name: raw:
  let
    platforms = raw.platforms or allSystems;
    enabled = lib.elem system platforms;

    shared = lib.removeAttrs raw reserved;
    perPlatform = raw.${system} or { };
    conf = shared // perPlatform;

    isBundle = conf.bundle or false;

    targetVer = conf.version or "unstable";
    env = envs.${targetVer};
    # Bundle packages always come from regular pkgs (never pkgsStatic).
    base = if (!isBundle && (conf.isStatic or true)) then env.pkgsStatic else env.pkgs;

    rawPkg = base.${name} or (lib.attrByPath (lib.splitString "." name) null base);

    selectedOutputs = conf.output or [ "out" ];
    finalName = conf.alias or name;

    standaloneDrv = env.pkgs.symlinkJoin {
      name = finalName;
      paths = map (o: lib.getOutput o rawPkg) selectedOutputs;
    };

    # Bundle outputs are already finished payloads; tag them so the caller
    # skips the standalone normalization step.
    bundleDrv = (makeBundle finalName rawPkg) // {
      __isBundle = true;
    };

    finalDrv = if isBundle then bundleDrv else standaloneDrv;
  in
  lib.optionalAttrs enabled {
    "${finalName}" = finalDrv;
  }
) manifest
