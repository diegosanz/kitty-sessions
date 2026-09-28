#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/helpers.sh"

lock_file() {
  echo "$(data_dir)/watch-${KITTY_PID:-unknown}.lock"
}

lock_owner_alive() {
  local pid
  pid="$(cat "$1" 2>/dev/null)"
  [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null
}

another_watcher_running() {
  local lock
  lock="$(lock_file)"
  [ -f "$lock" ] && [ "$(cat "$lock" 2>/dev/null)" != "$$" ] && lock_owner_alive "$lock"
}

remove_stale_locks() {
  local lock
  for lock in "$(data_dir)"/watch-*.lock; do
    [ -f "$lock" ] || continue
    lock_owner_alive "$lock" || rm -f "$lock"
  done
}

acquire_lock() {
  mkdir -p "$(data_dir)"
  remove_stale_locks
  another_watcher_running && exit 0
  echo "$$" > "$(lock_file)"
  trap 'rm -f "$(lock_file)"' EXIT
}

declare -A tracked_windows=()
previous_sessions=""

refresh_window() {
  local window_id="$1" cwd="$2" exes="$3" cmdlines="$4" title="$5" agent status session_id
  if ! find_agent "$exes"; then
    if [ -n "${tracked_windows[$window_id]:-}" ]; then
      reset_tab_title "$window_id"
      unset 'tracked_windows[$window_id]'
    fi
    return 0
  fi
  status="$(window_status "$agent" "$window_id")"
  tracked_windows[$window_id]="$agent"
  set_tab_status "$window_id" "$status" "$title"
  session_id="$(agent_discover_session "$cwd" "$cmdlines")"
  [ -n "$session_id" ] && current_sessions+="$agent:$session_id:$cwd"$'\n'
  return 0
}

forget_closed_windows() {
  local seen="$1" window_id
  for window_id in "${!tracked_windows[@]}"; do
    grep -qxF "$window_id" <<< "$seen" && continue
    unset 'tracked_windows[$window_id]'
  done
}

autosave_if_changed() {
  if [ "$current_sessions" != "$previous_sessions" ]; then
    previous_sessions="$current_sessions"
    "$SCRIPTS_DIR/save.sh" auto || true
  fi
}

cycle() {
  local listing seen="" window_id cwd exes cmdlines title
  listing="$(kitten_ls)" || return 1
  current_sessions=""
  while IFS=$'\t' read -r window_id cwd exes cmdlines title; do
    [ -n "$window_id" ] || continue
    seen+="$window_id"$'\n'
    refresh_window "$window_id" "$cwd" "$exes" "$cmdlines" "$title"
  done <<< "$listing"
  forget_closed_windows "$seen"
  autosave_if_changed
}

kitty_alive() {
  [ -z "${KITTY_PID:-}" ] || kill -0 "$KITTY_PID" 2>/dev/null
}

bounded_cycles() {
  [ -n "${KITTY_AGENTS_ONCE:-}" ]
}

cycles_left() {
  bounded_cycles || return 0
  [ "$KITTY_AGENTS_ONCE" -gt 0 ] || return 1
  KITTY_AGENTS_ONCE=$((KITTY_AGENTS_ONCE - 1))
}

pause() {
  if ! bounded_cycles; then
    sleep "$(poll_interval)"
  fi
}

acquire_lock
while kitty_alive && cycles_left; do
  cycle
  pause
done
