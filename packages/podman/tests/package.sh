#!/usr/bin/env bash
# Exercise installed entrypoints and actual vendored config readers without namespaces.
set -euo pipefail
source_root=$1
check=$(mktemp -d)
trap 'rm -rf "$check"' EXIT
root="$check/relocated podman & bundle"
cp -aL "$source_root" "$root"
chmod -R u+w "$root"
host="$check/host"
mkdir -p "$host"
cat >"$host/systemctl" <<'SH'
#!/bin/sh
printf '%s\n' "$*" >>"$SYSTEMCTL_LOG"
SH
chmod +x "$host/systemctl"
export SYSTEMCTL_LOG="$check/systemctl.log"
export PATH="$host:$PATH"
unit_dir="$check/units"
mkdir -p "$unit_dir"
# Redirect standard systemd paths only in this disposable test copy.
install_script=$(<"$root/bin/install.sh")
printf '%s\n' "${install_script//\/etc\/systemd\/system/"$unit_dir"}" >"$root/bin/install.sh"

# Installation only sets up systemd; network configuration is used in place.
"$root/bin/install.sh"
test ! -e "$root/data"
test "$(cat "$SYSTEMCTL_LOG")" = $'daemon-reload
enable --now podmanxd.socket'
grep -F 'ExecStart="'"$root/bin/podman-server"'"' "$unit_dir/podmanxd.service"
"$root/bin/install.sh"
test ! -e "$root/data"

# The runtime setup runs unchanged, but the final exec checks config without libpod initialization.
mv "$root/bin/_podman" "$root/bin/_podman.real"
cp "$root/bin/config-check" "$root/bin/_podman"
CONTAINERS_CONF_OVERRIDE=/nonexistent STORAGE_DRIVER=vfs STORAGE_OPTS=invalid \
  CONTAINERS_REGISTRIES_CONF_OVERRIDE=/nonexistent \
  XDG_CONFIG_HOME=/nonexistent XDG_DATA_HOME=/nonexistent XDG_CACHE_HOME=/nonexistent \
  SSL_CERT_FILE=/nonexistent SSL_CERT_DIR=/nonexistent \
  "$root/bin/podman-server"
test ! -e "$root/data/networks"
test ! -e "$root/data/containers.conf"
test ! -e "$root/conf/seccomp.json"
# A remote command must not create or require server state.
mv "$root/data" "$root/saved-data"
SSL_CERT_FILE=/nonexistent SSL_CERT_DIR=/nonexistent "$root/bin/podman" info
test ! -e "$root/data"
mv "$root/saved-data" "$root/data"

export CONTAINERS_CONF="$root/conf/containers.conf"
export CONTAINERS_STORAGE_CONF="$root/conf/storage.conf"
export PODMAN_DATA_DIR="$root/data"
for name in conmon crun runc pasta catatonit netavark aardvark-dns; do
  cp "$root/libexec/podman/$name" "$host/$name"
  expected="$root/libexec/podman/$name"
  test "$(CONTAINERS_HELPER_BINARY_DIR="$host" "$root/bin/config-check" helper "$name")" = "$expected"
  mv "$expected" "$expected.disabled"
  if CONTAINERS_HELPER_BINARY_DIR="$host" "$root/bin/config-check" helper "$name"; then
    echo "Escaped packaged helper directory for $name" >&2
    exit 1
  fi
  mv "$expected.disabled" "$expected"
done
# Missing policy must fail instead of silently using a host policy.
if CONTAINERS_REGISTRIES_CONF="$root/conf/registries.conf" \
  CONTAINERS_POLICY_JSON="$check/missing-policy" "$root/bin/config-check"; then exit 1; fi
"$root/bin/_podman.real" --version
"$root/libexec/podman/nft" --version
"$root/libexec/podman/crun" --version
"$root/libexec/podman/runc" --version
"$root/libexec/podman/pasta" --version
