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
