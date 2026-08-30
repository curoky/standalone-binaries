{
  pkgs,
  artifactTool,
}:
name: drv:
let
  isDarwin = pkgs.stdenv.hostPlatform.isDarwin;
  allowDynamicElf = pkgs.lib.elem name [
    "music-decrypto"
    "nsight-systems"
  ];
in
pkgs.runCommand "${name}-standalone"
  {
    outputs = [
      "out"
      "archive"
    ];
    nativeBuildInputs = [
      artifactTool
    ]
    ++ pkgs.lib.optional (!isDarwin) pkgs.buildPackages.binutils
    # artifact uses cctools for guarded Mach-O relocation and the Darwin
    # host's /usr/bin/codesign to preserve existing signature entitlements.
    # sigtool 0.1.3 cannot preserve signature metadata.
    ++ pkgs.lib.optional isDarwin pkgs.darwin.cctools;
  }
  ''
    artifact \
      --source ${drv} \
      --output "$out" \
      --archive "$archive" \
      --name ${pkgs.lib.escapeShellArg name} \
      --platform ${if isDarwin then "darwin" else "linux"} \
      ${pkgs.lib.optionalString allowDynamicElf "--allow-dynamic-elf"}
  ''
