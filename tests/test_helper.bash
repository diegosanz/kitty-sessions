ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

setup() {
  export PATH="$ROOT/tests/fakes:$ROOT/bin:$PATH"
  export KITTY_SESSIONS_DATA_DIR="$BATS_TEST_TMPDIR/data"
  export KITTEN_FAKE_LOG="$BATS_TEST_TMPDIR/kitten.log"
  export KITTEN_FAKE_LS="$BATS_TEST_TMPDIR/ls.json"
  export CLAUDE_CONFIG_DIR="$BATS_TEST_TMPDIR/claude"
  export HOME="$BATS_TEST_TMPDIR/home"
  export KITTY_PID=""
  export KITTY_SESSIONS_ONCE=1
  unset KITTY_SESSIONS_INTERVAL KITTY_SESSIONS_HISTORY
  mkdir -p "$HOME"
  : > "$KITTEN_FAKE_LOG"
}

window_json() {
  local id="$1" cwd="$2" title="$3"
  shift 3
  local cmdline pid="${WINDOW_PID:-1}"
  cmdline="$(printf '%s\n' "$@" | jq -R . | jq -s .)"
  jq -n --argjson id "$id" --arg cwd "$cwd" --arg title "$title" --argjson cmdline "$cmdline" --argjson pid "$pid" \
    '{id: $id, cwd: $cwd, title: $title, foreground_processes: [{pid: $pid, cwd: $cwd, cmdline: $cmdline}]}'
}

claude_process_file() {
  local pid="$1" id="$2" cwd="$3"
  mkdir -p "$CLAUDE_CONFIG_DIR/sessions"
  jq -n --argjson pid "$pid" --arg id "$id" --arg cwd "$cwd" '{pid: $pid, sessionId: $id, cwd: $cwd}' > "$CLAUDE_CONFIG_DIR/sessions/$pid.json"
}

write_ls() {
  local target="${1:-$KITTEN_FAKE_LS}"
  jq -s '[{tabs: [{is_active: false, windows: .}]}]' > "$target"
}

write_active_ls() {
  local target="${1:-$KITTEN_FAKE_LS}"
  jq -s '[{tabs: [{is_active: true, windows: .}]}]' > "$target"
}

tab_title_calls() {
  grep '^set-tab-title' "$KITTEN_FAKE_LOG" || true
}

claude_session_file() {
  local cwd="$1" id="$2" title="${3:-}" dir
  dir="$CLAUDE_CONFIG_DIR/projects/$(sed 's/[^A-Za-z0-9]/-/g' <<< "$cwd")"
  mkdir -p "$dir"
  if [ -n "$title" ]; then
    printf '{"type":"custom-title","customTitle":"%s"}\n' "$title" > "$dir/$id.jsonl"
  else
    : > "$dir/$id.jsonl"
  fi
}

last_snapshot_rows() {
  cat "$KITTY_SESSIONS_DATA_DIR/last"
}
