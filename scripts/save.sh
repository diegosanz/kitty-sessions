#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/helpers.sh"

mode="${1:-manual}"

rows="$(snapshot_rows "$(kitten_ls)")"
count="$(printf '%s' "$rows" | grep -c . || true)"

if [ "$count" -eq 0 ] && [ "$mode" = "auto" ]; then
  exit 0
fi

write_snapshot "${rows:+$rows$'\n'}" >/dev/null
[ "$mode" = "manual" ] && echo "Saved"
exit 0
