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
grep -Fx 'RuntimeDirectory=podman' "$unit_dir/podmanxd.service"
grep -Fx 'RuntimeDirectoryPreserve=yes' "$unit_dir/podmanxd.service"
"$root/bin/install.sh"
test ! -e "$root/data"

# The runtime setup runs unchanged, but the final exec checks config without libpod initialization.
mv "$root/bin/_podman" "$root/bin/_podman.real"
cp "$root/bin/config-check" "$root/bin/_podman"
runtime="$check/runtime"
sed -i "s|/run/podman|$runtime|g" "$root/bin/podman-server"
CONTAINERS_CONF_OVERRIDE=/nonexistent STORAGE_DRIVER=vfs STORAGE_OPTS=invalid \
	CONTAINERS_REGISTRIES_CONF_OVERRIDE=/nonexistent \
	XDG_CONFIG_HOME=/nonexistent XDG_DATA_HOME=/nonexistent XDG_CACHE_HOME=/nonexistent \
	SSL_CERT_FILE=/nonexistent SSL_CERT_DIR=/nonexistent \
	"$root/bin/podman-server"
test -d "$runtime/tmp"
test ! -e "$root/data/runroot"
test ! -e "$root/data/tmpdir"
test ! -e "$root/data/networks"
test ! -e "$root/data/containers.conf"
test ! -e "$root/conf/seccomp.json"
test ! -e "$root/lib/tmpfiles.d"
# A remote command must not create or require server state.
mv "$root/data" "$root/saved-data"
CONTAINERS_CONF=/nonexistent CONTAINERS_STORAGE_CONF=/nonexistent \
	CONTAINERS_REGISTRIES_CONF=/nonexistent CONTAINERS_POLICY_JSON=/nonexistent \
	SSL_CERT_FILE=/nonexistent SSL_CERT_DIR=/nonexistent "$root/bin/podman" info
test ! -e "$root/data"
mv "$root/saved-data" "$root/data"

export CONTAINERS_CONF="$root/conf/containers.conf"
export CONTAINERS_STORAGE_CONF="$root/conf/storage.conf"
export CONTAINERS_REGISTRIES_CONF="$root/conf/registries.conf"
export CONTAINERS_POLICY_JSON="$root/conf/policy.json"
export PODMAN_DATA_DIR="$root/data"
export PODMAN_RUNTIME_DIR="$runtime"
# The native config resolver uses the sibling helper directory. Conmon and OCI
# runtimes use the wrapper's package-first PATH.
PATH="$root/libexec/podman:$host" "$root/bin/config-check"
# catatonit is the one upstream lookup that checks a host absolute path before
# the configured helper directory; the small source patch removes that branch.
cp "$root/libexec/podman/catatonit" "$host/catatonit"
mv "$root/libexec/podman/catatonit" "$root/libexec/podman/catatonit.disabled"
if PATH="$host" "$root/bin/config-check" helper catatonit; then
	echo 'catatonit escaped the configured helper directory' >&2
	exit 1
fi
mv "$root/libexec/podman/catatonit.disabled" "$root/libexec/podman/catatonit"
# Missing policy must fail instead of silently using a host policy.
if CONTAINERS_REGISTRIES_CONF="$root/conf/registries.conf" \
	CONTAINERS_POLICY_JSON="$check/missing-policy" "$root/bin/config-check"; then exit 1; fi
"$root/bin/_podman.real" --version
"$root/libexec/podman/nft" --version
"$root/libexec/podman/crun" --version
"$root/libexec/podman/runc" --version
"$root/libexec/podman/pasta" --version
