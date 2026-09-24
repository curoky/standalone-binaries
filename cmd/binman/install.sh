#!/usr/bin/env bash

# Bootstrap installer for bm. It uses curl and tar because bm is not available yet.
set -euo pipefail

PREFIX="${BINMAN_PREFIX:-$HOME/.local}"
ARCH="${BINMAN_ARCH:-}"

die() {
  echo "error: $*" >&2
  exit 1
}

usage() {
  cat <<'EOF'
Usage:
  install.sh [--prefix DIR] [--arch ARCH]

Options:
  --prefix DIR  Package prefix (default: ~/.local)
  --arch ARCH   linux-x86_64 | linux-arm64 | darwin-arm64

Environment:
  BINMAN_PREFIX
  BINMAN_ARCH
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --prefix | --prefix=*)
      if [ "$1" = "--prefix" ]; then
        [ $# -ge 2 ] || die "--prefix requires a value"
        PREFIX="$2"
        shift 2
      else
        PREFIX="${1#*=}"
        shift
      fi
      ;;
    --arch | --arch=*)
      if [ "$1" = "--arch" ]; then
        [ $# -ge 2 ] || die "--arch requires a value"
        ARCH="$2"
        shift 2
      else
        ARCH="${1#*=}"
        shift
      fi
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *) die "unexpected argument: $1" ;;
  esac
done

[ -n "$PREFIX" ] || die "prefix must not be empty"
command -v curl >/dev/null 2>&1 || die "curl is required"
command -v tar >/dev/null 2>&1 || die "tar is required"

if [ -z "$ARCH" ]; then
  case "$(uname -s)/$(uname -m)" in
    Linux/x86_64 | Linux/amd64) ARCH="linux-x86_64" ;;
    Linux/aarch64 | Linux/arm64) ARCH="linux-arm64" ;;
    Darwin/arm64 | Darwin/aarch64) ARCH="darwin-arm64" ;;
    *) die "unsupported platform; pass --arch linux-x86_64, linux-arm64 or darwin-arm64" ;;
  esac
fi

case "$ARCH" in
  linux-x86_64 | linux-arm64 | darwin-arm64) ;;
  *) die "unsupported arch: $ARCH" ;;
esac

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

curl -fsSL \
  -o "$tmp/token.json" \
  "https://ghcr.io/token?scope=repository:curoky/standalone-binaries:pull"
token="$(tr ',' '\n' <"$tmp/token.json" |
  grep -o '"token":"[^"]*"' | head -n1 | cut -d'"' -f4)"
[ -n "$token" ] || die "failed to obtain registry token"

curl -fsSL \
  -H "Authorization: Bearer ${token}" \
  -H "Accept: application/vnd.oci.image.manifest.v1+json" \
  -o "$tmp/manifest.json" \
  "https://ghcr.io/v2/curoky/standalone-binaries/manifests/binman-${ARCH}"
digest="$(tr ',' '\n' <"$tmp/manifest.json" |
  grep -o '"digest":"sha256:[a-f0-9]*"' | tail -n1 | cut -d'"' -f4)"
[ -n "$digest" ] || die "could not resolve binman-$ARCH"

curl -fsSL \
  -H "Authorization: Bearer ${token}" \
  -o "$tmp/binman.tar.gz" \
  "https://ghcr.io/v2/curoky/standalone-binaries/blobs/${digest}"
tar -xzf "$tmp/binman.tar.gz" -C "$tmp"
[ -f "$tmp/binman/bin/bm" ] || die "archive did not contain binman/bin/bm"
chmod +x "$tmp/binman/bin/bm"
printf '{"digest":"%s","linkTo":["."]}\n' "$digest" >"$tmp/binman/.binman-meta"

mkdir -p "$PREFIX/.binman/store" "$PREFIX/bin"
rm -rf "$PREFIX/.binman/store/binman"
mv "$tmp/binman" "$PREFIX/.binman/store/binman"
rm -f "$PREFIX/bin/bm"
ln -s "../.binman/store/binman/bin/bm" "$PREFIX/bin/bm"

echo "> Installed: $PREFIX/bin/bm"
case ":$PATH:" in
  *":$PREFIX/bin:"*) echo "> bm is on PATH and ready." ;;
  *)
    echo "> Add bm to PATH:"
    echo "    export PATH=\"$PREFIX/bin:\$PATH\""
    ;;
esac
