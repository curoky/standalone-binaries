#!/bin/sh
# Stage one user's service in the host s6-rc source tree. The deployment owns
# the single compile/live-update step for the complete service database.
set -eu

if [ "$#" -ne 1 ]; then
	echo "usage: $0 USER" >&2
	exit 2
fi

root=$(readlink -f -- "$0")
root=$(CDPATH="" cd -- "${root%/*}/.." && pwd)
busybox="$root/libexec/podman/busybox"
user=$1
uid=$("$busybox" id -u "$user")
if [ "$uid" -eq 0 ]; then
	echo "rootless Podman requires a non-root user" >&2
	exit 2
fi
source_dir=/etc/s6/s6-rc.d
service="podman-$uid"
service_dir="$source_dir/$service"
escaped_root=$(printf '%s' "$root" | sed 's/[\&|]/\\&/g')
escaped_user=$(printf '%s' "$user" | sed 's/[\&|]/\\&/g')
s6_setuidgid=$(command -v s6-setuidgid)
escaped_s6_setuidgid=$(printf '%s' "$s6_setuidgid" | sed 's/[\&|]/\\&/g')
export PATH="$root/libexec/podman:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

for helper in newuidmap newgidmap; do
	if ! command -v "$helper" >/dev/null 2>&1; then
		echo "rootless Podman requires the host $helper package" >&2
		exit 1
	fi
done
"$busybox" mkdir -p "$service_dir" "$source_dir/default/contents.d"
"$busybox" cp "$root/conf/s6-rc.d/podman/type" "$service_dir/type"
sed \
	-e "s|@PODMAN_ROOT@|$escaped_root|g" \
	-e "s|@PODMAN_USER@|$escaped_user|g" \
	-e "s|@PODMAN_UID@|$uid|g" \
	-e "s|@S6_SETUIDGID@|$escaped_s6_setuidgid|g" \
	"$root/conf/s6-rc.d/podman/run" >"$service_dir/run"
sed \
	-e "s|@PODMAN_ROOT@|$escaped_root|g" \
	-e "s|@PODMAN_USER@|$escaped_user|g" \
	-e "s|@S6_SETUIDGID@|$escaped_s6_setuidgid|g" \
	"$root/conf/s6-rc.d/podman/finish" >"$service_dir/finish"
"$busybox" chmod 0755 "$service_dir/run" "$service_dir/finish"
: >"$source_dir/default/contents.d/$service"
