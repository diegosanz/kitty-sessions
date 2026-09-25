#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/helpers.sh"

window_id="${1:-${KITTY_WINDOW_ID:-}}"
[ -n "$window_id" ] || { echo "usage: kitty-agents status <window_id>" >&2; exit 1; }

while IFS=$'\t' read -r id cwd exes cmdlines title; do
  [ "$id" = "$window_id" ] || continue
  find_agent "$exes" || { echo "no-agent"; exit 0; }
  status="$(window_status "$agent" "$id")"
  echo "$agent ${status:-unknown}"
  exit 0
done < <(kitten_ls)

echo "no-window" >&2
exit 1
