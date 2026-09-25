#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/helpers.sh"

snapshot="$(last_snapshot)"
if [ ! -f "$snapshot" ]; then
  echo "nothing to restore"
  exit 0
fi

already_open_sessions="$(open_sessions)"
restored=0
already_open=0
missing_dir=0
unavailable=0

is_open() {
  printf '%s\n' "$already_open_sessions" | grep -qxF "$1"
}

skip() {
  echo "skip: $2" >&2
  eval "$1=\$(($1 + 1))"
}

launch_tab() {
  local cwd="$1"
  shift
  kitten @ launch --type=tab --cwd "$cwd" -- "$@" >/dev/null
}

while IFS=$'\t' read -r agent session_id cwd name saved_at; do
  [ -n "$agent" ] || continue
  if is_open "$session_id"; then
    skip already_open "$agent session $session_id is already open"
    continue
  fi
  if [ ! -d "$cwd" ]; then
    skip missing_dir "directory $cwd no longer exists ($name)"
    continue
  fi
  if ! agent_available "$agent"; then
    skip unavailable "agent '$agent' is not available ($name)"
    continue
  fi
  launch_tab "$cwd" $(agent_resume "$session_id")
  restored=$((restored + 1))
done < "$snapshot"

summary="restored $restored agent session(s)"
[ "$already_open" -gt 0 ] && summary="$summary, $already_open already open"
[ "$missing_dir" -gt 0 ] && summary="$summary, $missing_dir with missing directory"
[ "$unavailable" -gt 0 ] && summary="$summary, $unavailable with agent not installed"
echo "$summary"
