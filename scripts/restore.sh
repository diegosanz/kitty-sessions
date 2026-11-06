#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/helpers.sh"

name="${1:-}"
snapshot="$(snapshot_for "$name")"
if [ ! -f "$snapshot" ]; then
  if is_auto_session "$name"; then
    echo "nothing to restore"
    exit 0
  fi
  echo "no session named $name" >&2
  exit 1
fi

already_open_sessions="$(open_sessions)"
already_open_shell_cwds="$(open_shell_cwds)"

listed_in() {
  printf '%s\n' "$1" | grep -qxF "$2"
}

launch_tab() {
  local cwd="$1"
  shift
  kitten @ launch --type=tab --cwd "$cwd" "$@"
}

python_escaped() {
  sed 's/\\/\\\\/g' <<< "$1"
}

type_into_window() {
  kitten @ send-text -m "id:$1" "$(python_escaped "$2")" >/dev/null
}

restore_shell() {
  local cwd="$1" command="$2" window_id
  listed_in "$already_open_shell_cwds" "$cwd" && return 0
  window_id="$(launch_tab "$cwd")"
  [ "$command" != "$EMPTY_FIELD" ] && type_into_window "$window_id" "$command"
  return 0
}

tab_title_options() {
  agent_has_tab_title || return 0
  printf -- '--tab-title\n%s\n' "$(agent_tab_title)"
}

restore_agent() {
  local agent="$1" session_id="$2" cwd="$3" title_options
  listed_in "$already_open_sessions" "$session_id" && return 0
  agent_available "$agent" || return 0
  mapfile -t title_options < <(tab_title_options)
  launch_tab "$cwd" "${title_options[@]}" -- $(agent_resume "$session_id") >/dev/null
}

close_invoking_tab() {
  [ -n "${KITTY_WINDOW_ID:-}" ] || return 0
  kitten @ close-tab -m "window_id:$KITTY_WINDOW_ID" >/dev/null 2>&1 || true
}

while IFS=$'\t' read -r agent session_id cwd name saved_at; do
  [ -n "$agent" ] || continue
  [ -d "$cwd" ] || continue
  if [ "$agent" = "$SHELL_ROW" ]; then
    restore_shell "$cwd" "$name"
  else
    restore_agent "$agent" "$session_id" "$cwd"
  fi
done < "$snapshot"

echo "Restored"
close_invoking_tab
