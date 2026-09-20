#!/usr/bin/env bash
# Exercise the relocated rootless wrappers and installer without namespaces.
set -euo pipefail
source_root=$1
base_root=$2
check=$(mktemp -d)
trap 'rm -rf "$check"' EXIT
root="$check/relocated podman rootless & bundle"
cp -aL "$source_root" "$root"
chmod -R u+w "$root"

# The rootless package is a thin overlay. Common payload and policy must remain
# byte-identical to the matching rootful package.
cmp "$root/bin/_podman" "$base_root/bin/_podman"
cmp "$root/conf/ca-bundle.crt" "$base_root/conf/ca-bundle.crt"
cmp "$root/conf/containers.conf" "$base_root/conf/containers.conf"
cmp "$root/conf/registries.conf" "$base_root/conf/registries.conf"
cmp "$root/conf/policy.json" "$base_root/conf/policy.json"
cmp "$root/conf/mounts.conf" "$base_root/conf/mounts.conf"
cmp "$root/libexec/podman/crun" "$base_root/libexec/podman/crun"
test -x "$root/bin/podman"
test -x "$root/bin/podman-server"
test ! -e "$root/bin/podman-stop"
cmp "$root/bin/docker" "$root/bin/podman"
test ! -e "$root/conf/podmanxd.service"
test ! -e "$root/conf/podmanxd.socket"
test ! -e "$root/lib/tmpfiles.d"
test ! -e "$root/libexec/podman/quadlet"
test -d "$root/conf/networks"
test -z "$(find "$root/conf/networks" -mindepth 1 -print -quit)"

# The installer only stages a rendered service in the s6-rc source tree; the
# deployment owns the single database compile/live-update step.
test "$(cat "$root/conf/s6-rc.d/podman/type")" = longrun
source_dir="$check/s6-rc.d"
mkdir -p "$source_dir/default/contents.d"
printf '%s\n' bundle >"$source_dir/default/type"
install_script=$(<"$root/bin/install.sh")
install_script=${install_script//\/etc\/s6\/s6-rc.d/"$source_dir"}
host_helpers="$check/host-helpers"
mkdir -p "$host_helpers"
printf '#!/bin/sh\nexec "$@"\n' >"$host_helpers/s6-setuidgid"
chmod +x "$host_helpers/s6-setuidgid"
install_script=${install_script//\/usr\/local\/sbin:\/usr\/local\/bin:\/usr\/sbin:\/usr\/bin:\/sbin:\/bin/"$host_helpers"}
printf '%s\n' "$install_script" >"$root/bin/install.sh"
if PATH="$host_helpers:$PATH" "$root/bin/install.sh" "$(id -un)" 2>"$check/missing-helper.log"; then
	echo 'installer accepted missing host ID-map helpers' >&2
	exit 1
fi
grep -F 'requires the host newuidmap package' "$check/missing-helper.log"
printf '#!/bin/sh\nexit 0\n' >"$host_helpers/newuidmap"
printf '#!/bin/sh\nexit 0\n' >"$host_helpers/newgidmap"
chmod +x "$host_helpers/newuidmap" "$host_helpers/newgidmap"
user=$(id -un)
uid=$(id -u)
service="podman-$uid"
PATH="$host_helpers:$PATH" "$root/bin/install.sh" "$user"
PATH="$host_helpers:$PATH" "$root/bin/install.sh" "$user"
test "$(cat "$source_dir/$service/type")" = longrun
grep -F "root=\"$root\"" "$source_dir/$service/run"
grep -F "user=\"$user\"" "$source_dir/$service/run"
grep -F "uid=\"$uid\"" "$source_dir/$service/run"
grep -F "\"\$root/data\"" "$source_dir/$service/run"
grep -F "exec $host_helpers/s6-setuidgid \"\$user\"" "$source_dir/$service/run"
grep -F "root=\"$root\"" "$source_dir/$service/finish"
grep -F "exec $host_helpers/s6-setuidgid \"\$user\"" "$source_dir/$service/finish"
# The rendered service must retain its runtime root variable.
# shellcheck disable=SC2016
grep -F -- '"$root/bin/podman-server" --stop-all' "$source_dir/$service/finish"
test -e "$source_dir/default/contents.d/$service"
if grep -IRn 'systemd|systemctl|podman-rootlessd\.(service|socket)' \
	"$root/bin" "$root/conf" "$root/lib"; then
	echo 'rootless bundle still contains systemd integration' >&2
	exit 1
fi
test ! -e "$root/data"

# Redirect /run only in this disposable wrapper copy. Persistent state must
# resolve naturally relative to the relocated bundle.
runtime="$check/runtime"
sed -i \
	-e "s|^export PODMAN_RUNTIME_DIR=.*|export PODMAN_RUNTIME_DIR=\"$runtime\"|" \
	"$root/bin/podman-server"
cat >"$root/bin/_podman" <<'SH'
#!/bin/sh
{
  printf 'HOME=%s\n' "${HOME-}"
  printf 'XDG_RUNTIME_DIR=%s\n' "${XDG_RUNTIME_DIR-}"
  printf 'TMPDIR=%s\n' "${TMPDIR-}"
  printf 'USER=%s\n' "${USER-}"
  printf 'LOGNAME=%s\n' "${LOGNAME-}"
  printf 'PODMAN_DATA_DIR=%s\n' "${PODMAN_DATA_DIR-}"
  printf 'PODMAN_RUNTIME_DIR=%s\n' "${PODMAN_RUNTIME_DIR-}"
  printf 'CONTAINERS_CONF=%s\n' "${CONTAINERS_CONF-}"
  printf 'CONTAINERS_STORAGE_CONF=%s\n' "${CONTAINERS_STORAGE_CONF-}"
  printf 'arg=%s\n' "$@"
} >"$PODMAN_TEST_LOG"
SH
chmod +x "$root/bin/_podman"

export PODMAN_TEST_LOG="$check/server.log"
CONTAINERS_CONF_OVERRIDE=/nonexistent STORAGE_DRIVER=vfs STORAGE_OPTS=invalid \
	XDG_CONFIG_HOME=/nonexistent XDG_DATA_HOME=/nonexistent XDG_CACHE_HOME=/nonexistent \
	"$root/bin/podman-server"
grep -Fx "HOME=$root/data/home" "$PODMAN_TEST_LOG"
grep -Fx "XDG_RUNTIME_DIR=$runtime" "$PODMAN_TEST_LOG"
grep -Fx "TMPDIR=$runtime/tmp" "$PODMAN_TEST_LOG"
grep -Fx "USER=$user" "$PODMAN_TEST_LOG"
grep -Fx "LOGNAME=$user" "$PODMAN_TEST_LOG"
grep -Fx "PODMAN_DATA_DIR=$root/data" "$PODMAN_TEST_LOG"
grep -Fx "PODMAN_RUNTIME_DIR=$runtime" "$PODMAN_TEST_LOG"
grep -Fx "arg=--tmpdir=$runtime/libpod" "$PODMAN_TEST_LOG"
grep -Fx "arg=--network-config-dir=$root/conf/networks" "$PODMAN_TEST_LOG"
grep -Fx "arg=--default-mounts-file=$root/conf/mounts.conf" "$PODMAN_TEST_LOG"
grep -Fx 'arg=system' "$PODMAN_TEST_LOG"
grep -Fx 'arg=service' "$PODMAN_TEST_LOG"
grep -Fx "arg=unix://$runtime/podman.sock" "$PODMAN_TEST_LOG"
test -d "$root/data/home"
test -d "$runtime"

# The client has a distinct endpoint and must not create server state.
rm -rf "$root/data" "$runtime"
export PODMAN_TEST_LOG="$check/client.log"
"$root/bin/podman" info
grep -Fx 'arg=--remote' "$PODMAN_TEST_LOG"
grep -Fx "arg=--url=unix:///run/user/$uid/podman/podman.sock" "$PODMAN_TEST_LOG"
grep -Fx 'arg=info' "$PODMAN_TEST_LOG"
grep -Fx "CONTAINERS_CONF=$root/conf/containers.conf" "$PODMAN_TEST_LOG"
grep -Fx "CONTAINERS_STORAGE_CONF=$root/conf/storage.conf" "$PODMAN_TEST_LOG"
grep -Fx 'PODMAN_DATA_DIR=' "$PODMAN_TEST_LOG"
grep -Fx 'PODMAN_RUNTIME_DIR=' "$PODMAN_TEST_LOG"
test ! -e "$root/data"
test ! -e "$runtime"
cmp "$root/bin/docker" "$root/bin/podman"

# s6 finish reuses the server's local-engine environment after the API is gone.
sed -i \
	-e "s|^export PODMAN_RUNTIME_DIR=.*|export PODMAN_RUNTIME_DIR=\"$runtime\"|" \
	"$root/bin/podman-server"
mkdir -p "$root/data" "$runtime"
export PODMAN_TEST_LOG="$check/stop.log"
"$root/bin/podman-server" --stop-all
grep -Fx "arg=--tmpdir=$runtime/libpod" "$PODMAN_TEST_LOG"
grep -Fx "arg=--network-config-dir=$root/conf/networks" "$PODMAN_TEST_LOG"
grep -Fx 'arg=stop' "$PODMAN_TEST_LOG"
grep -Fx 'arg=--all' "$PODMAN_TEST_LOG"

# Subordinate-ID tools remain a host-managed security interface.
test ! -e "$root/libexec/podman/newuidmap"
test ! -e "$root/libexec/podman/newgidmap"
test ! -e "$root/bin/newuidmap"
test ! -e "$root/bin/newgidmap"
test -z "$(find "$root/conf/networks" -mindepth 1 -print -quit)"
