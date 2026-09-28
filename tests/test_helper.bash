ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

setup() {
  export PATH="$ROOT/tests/fakes:$ROOT/bin:$PATH"
  export KITTY_AGENTS_DATA_DIR="$BATS_TEST_TMPDIR/data"
  export KITTEN_FAKE_LOG="$BATS_TEST_TMPDIR/kitten.log"
  export KITTEN_FAKE_LS="$BATS_TEST_TMPDIR/ls.json"
  export CLAUDE_CONFIG_DIR="$BATS_TEST_TMPDIR/claude"
  export HOME="$BATS_TEST_TMPDIR/home"
  export KITTY_PID=""
  export KITTY_AGENTS_ONCE=1
  unset KITTY_AGENTS_INTERVAL KITTY_AGENTS_HISTORY
  mkdir -p "$HOME"
  : > "$KITTEN_FAKE_LOG"
}

window_json() {
  local id="$1" cwd="$2" title="$3"
  shift 3
  local cmdline
  cmdline="$(printf '%s\n' "$@" | jq -R . | jq -s .)"
  jq -n --argjson id "$id" --arg cwd "$cwd" --arg title "$title" --argjson cmdline "$cmdline" \
    '{id: $id, cwd: $cwd, title: $title, foreground_processes: [{pid: 1, cwd: $cwd, cmdline: $cmdline}]}'
}

write_ls() {
  local target="${1:-$KITTEN_FAKE_LS}"
  jq -s '[{tabs: [{windows: .}]}]' > "$target"
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
  cat "$KITTY_AGENTS_DATA_DIR/last"
}
