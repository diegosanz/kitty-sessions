#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/helpers.sh"

mode="${1:-manual}"

collect_rows() {
  local window_id cwd exes cmdlines title agent session_id name saved_at
  saved_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  while IFS=$'\t' read -r window_id cwd exes cmdlines title; do
    find_agent "$exes" || continue
    session_id="$(agent_discover_session "$cwd" "$cmdlines")"
    [ -n "$session_id" ] || continue
    name="$(agent_session_name "$session_id" "$cwd")"
    [ -n "$name" ] || name="$title"
    printf '%s\t%s\t%s\t%s\t%s\n' "$agent" "$session_id" "$cwd" "$name" "$saved_at"
  done < <(kitten_ls)
}

rows="$(collect_rows)"
count="$(printf '%s' "$rows" | grep -c . || true)"

if [ "$count" -eq 0 ] && [ "$mode" = "auto" ]; then
  exit 0
fi

write_snapshot "${rows:+$rows$'\n'}" >/dev/null
[ "$mode" = "manual" ] && echo "saved $count agent session(s)"
exit 0
