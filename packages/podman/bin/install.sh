#!/bin/sh
set -eu
root=$(readlink -f -- "$0")
root=$(CDPATH="" cd -- "${root%/*}/.." && pwd)
export PATH="$root/libexec/podman:$PATH"
escaped_root=$(printf '%s' "$root" | sed 's/[\&|]/\\&/g')
sed "s|@PODMANX_ROOT@|$escaped_root|g" "$root/conf/podmanxd.service" >/etc/systemd/system/podmanxd.service
cp "$root/conf/podmanxd.socket" /etc/systemd/system/podmanxd.socket
systemctl daemon-reload
systemctl enable --now podmanxd.socket
