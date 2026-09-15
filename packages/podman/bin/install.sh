#!/usr/bin/env bash
set -euo pipefail

script_path="$(readlink -f "$0")"
root=$(cd "$(dirname "$script_path")/.." && pwd)
systemd_unit_dir=${PODMANX_SYSTEMD_UNIT_DIR:-/etc/systemd/system}

mkdir -p "$root/data" "$systemd_unit_dir"
escaped_root=$(printf '%s' "$root" | sed 's/[\\&|]/\\&/g')
sed "s|@PODMANX_ROOT@|$escaped_root|g" \
  "$root/conf/podmanxd.service" >"$systemd_unit_dir/podmanxd.service"
cp "$root/conf/podmanxd.socket" "$systemd_unit_dir/podmanxd.socket"

systemctl daemon-reload
systemctl enable podmanxd.socket
systemctl start podmanxd.socket
systemctl status podmanxd.socket

# echo 'nvidia-ctk cdi generate --output=/etc/cdi/nvidia.yaml'
