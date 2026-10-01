#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage: connect.sh --runner <ubuntu-24.04-arm|macos-26> --ref <git-ref> [options]

Options:
  --key <path>  SSH private key (default: /workspace/.secrets/github-actions-debug)
  --dry-run     Validate prerequisites without dispatching a workflow
  -h, --help    Show this help
EOF
}

runner=
git_ref=
key_path=/workspace/.secrets/github-actions-debug
dry_run=false

while (($#)); do
  case "$1" in
    --runner)
      runner=${2:?missing value for --runner}
      shift 2
      ;;
    --ref)
      git_ref=${2:?missing value for --ref}
      shift 2
      ;;
    --key)
      key_path=${2:?missing value for --key}
      shift 2
      ;;
    --dry-run)
      dry_run=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

case "$runner" in
  ubuntu-24.04-arm|macos-26) ;;
  *)
    echo "--runner must be ubuntu-24.04-arm or macos-26" >&2
    exit 2
    ;;
esac

if [[ -z "$git_ref" ]]; then
  echo "--ref is required" >&2
  exit 2
fi

for command_name in gh git jq ssh ssh-keygen; do
  if ! command -v "$command_name" >/dev/null; then
    echo "required command not found: $command_name" >&2
    exit 1
  fi
done

if [[ ! -r "$key_path" ]]; then
  echo "SSH private key is not readable: $key_path" >&2
  exit 1
fi

repo_root=$(git rev-parse --show-toplevel)
cd "$repo_root"

repo=$(gh repo view --json nameWithOwner --jq .nameWithOwner)
public_key=$(ssh-keygen -y -f "$key_path" | awk '{ print $1 " " $2 }')

if ! git ls-remote --exit-code origin "$git_ref" >/dev/null; then
  echo "remote ref not found on origin: $git_ref" >&2
  exit 1
fi

printf 'repository: %s\nrunner: %s\nref: %s\n' \
  "$repo" "$runner" "$git_ref"

if [[ "$dry_run" == true ]]; then
  echo "dry-run complete; no workflow was dispatched"
  exit 0
fi

session="trae-$(date -u +%Y%m%dT%H%M%SZ)-${RANDOM}"
title="debug ARM $session on $runner"
artifact="upterm-$session"

gh workflow run debug-arm.yaml \
  --repo "$repo" \
  --ref "$git_ref" \
  -f "runner=$runner" \
  -f "session=$session" \
  -f "public_key=$public_key"

echo "workflow dispatched: $session"

run_id=
for _ in {1..120}; do
  runs=$(gh run list \
    --repo "$repo" \
    --workflow debug-arm.yaml \
    --event workflow_dispatch \
    --limit 30 \
    --json databaseId,displayTitle)
  run_id=$(jq -r --arg title "$title" \
    '.[] | select(.displayTitle == $title) | .databaseId' <<<"$runs" | head -1)
  if [[ -n "$run_id" ]]; then
    break
  fi
  sleep 5
done

if [[ -z "$run_id" ]]; then
  echo "timed out waiting for workflow run: $title" >&2
  exit 1
fi

run_url="https://github.com/$repo/actions/runs/$run_id"
echo "run: $run_url"

connection_dir=$(mktemp -d)
cleanup() {
  rm -rf -- "$connection_dir"
}
trap cleanup EXIT

for _ in {1..120}; do
  if gh run download "$run_id" \
    --repo "$repo" \
    --name "$artifact" \
    --dir "$connection_dir" 2>/dev/null; then
    break
  fi

  conclusion=$(gh run view "$run_id" --repo "$repo" \
    --json conclusion --jq '.conclusion // ""')
  if [[ -n "$conclusion" ]]; then
    echo "workflow ended before publishing SSH information: $conclusion" >&2
    gh run view "$run_id" --repo "$repo" --log-failed || true
    exit 1
  fi
  sleep 5
done

connection_file="$connection_dir/ssh-command"
if [[ ! -s "$connection_file" ]]; then
  echo "timed out waiting for SSH connection artifact" >&2
  exit 1
fi

read -r -a ssh_command <"$connection_file"
if [[ ${#ssh_command[@]} -lt 2 || ${ssh_command[0]} != ssh ]]; then
  echo "unexpected SSH command in artifact" >&2
  exit 1
fi

echo "connecting; run 'touch /continue' before exiting to release the runner"
cleanup
trap - EXIT
exec ssh \
  -tt \
  -i "$key_path" \
  -o IdentitiesOnly=yes \
  -o StrictHostKeyChecking=accept-new \
  "${ssh_command[@]:1}"
