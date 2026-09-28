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

previous_sessions=""
baseline_taken=""
declare -A previous_titles=()
declare -A bell_titles=()

ring_bell() {
  bell_titles[$1]="$2"
  show_bell "$1" "$2"
}

silence_bell() {
  unset 'bell_titles[$1]'
  hide_bell "$1"
}

update_bell() {
  local window_id="$1" title="$2" tab_active="$3"
  if [ "$tab_active" = true ] || ! agent_finished "$title"; then
    silence_bell "$window_id"
  elif [ "${bell_titles[$window_id]}" != "$title" ]; then
    ring_bell "$window_id" "$title"
  fi
}

ring_on_completion() {
  local window_id="$1" previous="$2" title="$3" tab_active="$4"
  [ -n "$previous" ] || return 0
  [ "$tab_active" = false ] || return 0
  agent_finished_transition "$previous" "$title" && ring_bell "$window_id" "$title"
  return 0
}

track_bell() {
  local window_id="$1" exes="$2" tab_active="$3" title="$4" previous
  previous="${previous_titles[$window_id]-}"
  previous_titles[$window_id]="$title"
  if ! find_agent "$exes" || ! agent_reports_completion; then
    [ -n "${bell_titles[$window_id]-}" ] && silence_bell "$window_id"
    return 0
  fi
  if [ -n "${bell_titles[$window_id]-}" ]; then
    update_bell "$window_id" "$title" "$tab_active"
  else
    ring_on_completion "$window_id" "$previous" "$title" "$tab_active"
  fi
}

track_bells() {
  local window_id cwd exes cmdlines pids tab_active title
  while IFS=$'\t' read -r window_id cwd exes cmdlines pids tab_active title; do
    [ -n "$window_id" ] || continue
    track_bell "$window_id" "$exes" "$tab_active" "$title"
  done <<< "$1"
  forget_closed_windows "$1"
}

forget_closed_windows() {
  local open_ids window_id
  open_ids="$(cut -f1 <<< "$1")"
  for window_id in "${!previous_titles[@]}"; do
    grep -qxF "$window_id" <<< "$open_ids" && continue
    unset 'previous_titles[$window_id]' 'bell_titles[$window_id]'
  done
}

autosave_if_changed() {
  [ "$current_sessions" != "$previous_sessions" ] || return 0
  previous_sessions="$current_sessions"
  if [ -z "$baseline_taken" ]; then
    baseline_taken=1
    return 0
  fi
  "$SCRIPTS_DIR/save.sh" auto || true
}

cycle() {
  local listing
  listing="$(kitten_ls)" || return 1
  track_bells "$listing"
  current_sessions="$(snapshot_rows "$listing" | snapshot_change_key)"
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
