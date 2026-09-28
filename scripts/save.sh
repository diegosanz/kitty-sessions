#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/helpers.sh"

mode="${1:-manual}"
name="${2:-}"

rows="$(snapshot_rows "$(kitten_ls)")"
count="$(printf '%s' "$rows" | grep -c . || true)"

if [ "$count" -eq 0 ] && [ "$mode" = "auto" ]; then
  exit 0
fi

rows="${rows:+$rows$'\n'}"
if is_auto_session "$name"; then
  write_snapshot "$rows" >/dev/null
  [ "$mode" = "manual" ] && echo "Saved"
else
  write_named_session "$name" "$rows" >/dev/null
  echo "Saved $name"
fi
exit 0
