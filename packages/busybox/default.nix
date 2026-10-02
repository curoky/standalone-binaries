# BusyBox — relocatable udhcpc resources.
#
# Why local:
# 1. Stock udhcpc compiles the Nix output path of `default.script` into the
#    executable. Hash normalization leaves that path nonexistent at runtime.
# 2. The generated dispatcher also calls BusyBox applets through the same
#    absolute output path.
# 3. The patch makes udhcpc resolve its script from `/proc/self/exe`; packaging
#    moves the script into the package and makes its applet calls `$0`-relative.
#
# Keep the resource packaging; remove the patch only when upstream supports a
# relocatable default dispatcher path.
{ busybox }:

(busybox.override {
  extraConfig = ''
    CONFIG_UDHCPC_DEFAULT_SCRIPT "../share/udhcpc/default.script"
  '';
}).overrideAttrs
  (oldAttrs: {
    patches = (oldAttrs.patches or [ ]) ++ [ ./relative-udhcpc-script.patch ];

    postInstall = (oldAttrs.postInstall or "") + ''
      mkdir -p "$out/share/udhcpc"
      substituteInPlace "$out/default.script" \
        --replace-fail "$out/bin/busybox" '"$busybox_root/bin/busybox"' \
        --replace-fail "$out/bin/logger" '"$busybox_root/bin/logger"'
      sed -i '2i busybox_root="''${0%/*}/../.."' "$out/default.script"
      mv "$out/default.script" "$out/share/udhcpc/default.script"
    '';
  })
