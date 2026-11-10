# Radare2 — relocatable analysis databases.
#
# Stock musl-static Radare2 builds without local compiler changes, but its
# compiled prefix points at the Nix output. After relocation, type matching
# cannot find the shipped SDB databases and reports unknown global types.
# Set the supported R2_PREFIX from each installed entry's resolved location.
# This resource wrapper is product packaging; remove it when stock Radare2
# locates its bundled data relative to the executable without an override.
{
  buildPackages,
  radare2,
  writeText,
}:
let
  wrapper = writeText "radare2-wrapper.sh" ''
    #!/usr/bin/env bash
    script_path=$(readlink -f "$0")
    root=$(cd "$(dirname "$script_path")/.." && pwd)
    name=''${script_path##*/}
    export R2_PREFIX="$root"
    exec -a "$0" "$root/bin/_$name" "$@"
  '';
in
radare2.overrideAttrs (old: {
  nativeInstallCheckInputs = (old.nativeInstallCheckInputs or [ ]) ++ [ buildPackages.coreutils ];
  versionCheckKeepEnvironment = (old.versionCheckKeepEnvironment or [ ]) ++ [ "PATH" ];

  postInstall = (old.postInstall or "") + ''
    for entry in "$out"/bin/*; do
      if [ -f "$entry" ] && [ ! -L "$entry" ]; then
        mv "$entry" "$out/bin/_''${entry##*/}"
        cp ${wrapper} "$entry"
        chmod +x "$entry"
      fi
    done
  '';
})
