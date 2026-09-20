# Stock BusyBox compiles its Nix output path into udhcpc as the default
# dispatcher script, and that generated script calls BusyBox through the same
# absolute path. Artifact hash normalization would make both paths nonexistent.
# Keep the dispatcher as a sibling resource and resolve both directions from
# /proc/self/exe and $0 so the complete DHCP behavior remains relocatable.
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
