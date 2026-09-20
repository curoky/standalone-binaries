# Rootless Podman Deployment Design

## Installation

Each bundle serves one non-root user and should be extracted to a directory
owned exclusively by that user, such as `/opt/podman`. Run
`bin/install.sh USER` as root. The installer resolves the user's UID, verifies
that `newuidmap`, `newgidmap`, and `s6-setuidgid` are available on the host
`PATH`, renders the service into `/etc/s6/s6-rc.d/podman-<uid>`, and adds it to
the `default` bundle. Root should own the bundle programs, fixed configuration,
and s6 templates so that the target user cannot modify scripts that root later
executes. Only `data`, `conf/networks`, and `/run/user/<uid>/podman` are handed
to the target user when the service starts.

The installer only writes the s6-rc source tree. The deployment must run one
`s6-rc-compile` after collecting all services, or one `s6-rc-update` when
updating a live system. The run script creates the required directories and
sets their ownership as root before using the host `s6-setuidgid` to execute
`bin/podman-server` as the target user. The server listens directly on the
user's socket. `podman-server` resets `USER` and `LOGNAME` from its post-drop
UID instead of inheriting root's identity, while `bin/podman` and `bin/docker`
connect using the current UID.

## Files and State

For a bundle installed at `/opt/podman` for UID `<uid>`:

| Content | Path | Lifetime |
| --- | --- | --- |
| Programs, helpers, and fixed configuration | `/opt/podman/bin`, `libexec/podman`, `conf` | Bundle |
| Images, containers, volumes, and database | `/opt/podman/data/graphroot` | Persistent |
| Engine home and registry credentials | `/opt/podman/data/home`, `data/auth.json` | Persistent |
| Network definitions | `/opt/podman/conf/networks` | Persistent; initially empty |
| Storage runroot | `/run/user/<uid>/podman/storage` | Volatile |
| libpod temporary directory | `/run/user/<uid>/podman/libpod` | Volatile |
| Image temporary files | `/run/user/<uid>/podman/tmp` | Volatile |
| API socket | `/run/user/<uid>/podman/podman.sock` | Volatile |

When the s6 service restarts, its `finish` script invokes
`podman-server --stop-all` to stop all containers through the local engine
after the API socket has closed, reusing the runtime directory for the current
boot. It cannot invoke `podman`, which is a remote client that only accesses
the socket. A host reboot clears `/run`; s6 recreates the runtime directories
on startup, while persistent state is restored from `/opt/podman`.

Back up or migrate the complete bundle, but do not copy
`/run/user/<uid>/podman`. Reinstall the service after changing the bundle path
or user UID. Never share one bundle between users, because they would then
share data and network definitions.

## Differences from the Rootful Base

The rootless derivation copies the corresponding rootful bundle, removes its
systemd units, Quadlet helper, and predefined bridge, then replaces only
`install.sh`, `podman`, `podman-server`, and the s6-rc templates. `_podman`,
helpers, the CA bundle, registry/signature/mount policies, `containers.conf`,
and `storage.conf` remain identical to the rootful base.

The shared configuration selects pasta as the default rootless network
command. The rootless `conf/networks` directory is initially empty and is
managed by Podman at runtime. It does not inherit the rootful bridge, modify
nftables, or enable forwarding. The wrapper appends the standard system
`PATH` only to find host security interfaces, while bundled helpers remain
first.

The rootless bundle adds no source patches; it inherits all patches from the
matching rootful version. See
[`../podman/DESIGN.md`](../podman/DESIGN.md#source-patches) for why those
patches cannot be replaced with configuration.

## Networking

Without an explicit network selection, rootless containers use pasta. Pasta
provides unprivileged userspace networking without creating a host bridge,
modifying host nftables, or requiring host IP forwarding. Bundled
`pasta`/`passt` helpers handle outbound traffic, DNS, and explicitly published
ports. The shared configuration selects this mode with
`default_rootless_network_cmd = "pasta"`. Explicit `--network` modes such as
host, none, and container namespaces retain their upstream Podman semantics.

Pasta requires access to `/dev/net/tun` on the host. The engine and image pulls
still work without it, but starting a container with the default network fails
when pasta tries to create a TAP device.

The rootless bundle removes the rootful `podman.json` bridge definition and
starts with an empty `conf/networks`. Netavark definitions created with
`podman network create` are written there and remain persistent with the
bundle. Netavark and pasta still operate within the rootless user namespace
when those networks are used. Pasta processes, the API socket, and network
runtime state disappear when the service or host restarts; network definitions
and container data remain, and networking is recreated when containers start
again.

## Portability and Host Interfaces

The bundle itself contains static musl artifacts and can be relocated as a
unit. Its BusyBox is the runtime tool explicitly used by Podman subprocesses
and s6 service scripts, providing `sh`, `readlink`, `mkdir`, `sed`, and `cp`.
Wrappers and the installer are still launched by a host POSIX shell and use
the host `readlink` before switching to the bundle `PATH`; the installer also
requires host `sed`, `printf`, and `command`.

The host must provide Linux unprivileged user namespaces, cgroup v2, native
rootless overlay, and device access. It must also configure non-overlapping
`/etc/subuid` and `/etc/subgid` ranges for the target user. Host shadow/uidmap
packages manage the setuid bits or file capabilities of `newuidmap` and
`newgidmap`. The installer checks for these programs, and the rootless engine
executes them when creating a user namespace. They are therefore host-managed
runtime security interfaces, not installation-only tools, and are not copied
into the bundle.

The filesystem containing `/opt/podman/data` must support unprivileged native
overlay. Overlay-on-overlay generally does not satisfy this requirement. The
bundle does not automatically fall back to VFS or fuse-overlayfs.

The host provides s6, s6-rc, and `s6-setuidgid` for installation and service
management. The bundle does not depend on systemd, provide a fuse-overlayfs
fallback, create users, edit subordinate-ID databases, or modify sysctls.
GPU/CDI support depends on host drivers, `/etc/cdi`, and device permissions for
the target user. External Docker-compatible clients can set
`DOCKER_HOST=unix:///run/user/<uid>/podman/podman.sock`.
