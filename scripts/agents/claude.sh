agent_label() {
  echo "Claude Code"
}

agent_binary() {
  echo "claude"
}

agent_matches() {
  grep -qw "claude" <<< "$1"
}

agent_discover_session() {
  local cwd="$1" cmdline="$2" pids="$3" id
  id="$(claude_session_from_pids "$pids")"
  [ -n "$id" ] || id="$(claude_session_from_cmdline "$cmdline")"
  [ -n "$id" ] || id="$(claude_newest_session "$cwd")"
  echo "$id"
}

agent_session_name() {
  local file="$(claude_project_dir "$2")/$1.jsonl"
  [ -f "$file" ] || return 0
  grep -o '"customTitle":"[^"]*"' "$file" | tail -1 | sed 's/^"customTitle":"//; s/"$//' || true
}

agent_resume() {
  printf 'claude -r %q' "$1"
}

agent_working() {
  [[ "$1" == ◐* || "$1" == ◑* ]]
}

agent_finished() {
  [[ "$1" == ✳* ]]
}

agent_finished_transition() {
  agent_working "$1" && agent_finished "$2"
}

claude_session_from_pids() {
  local pid file id
  for pid in $1; do
    file="$(claude_config_dir)/sessions/$pid.json"
    [ -f "$file" ] || continue
    id="$(jq -r '.sessionId // empty' "$file" 2>/dev/null || true)"
    [ -z "$id" ] || { echo "$id"; return 0; }
  done
}

claude_session_from_cmdline() {
  grep -oE -- '(--session-id|--resume|-r)[ =][0-9a-f-]{36}' <<< "$1" | grep -oE '[0-9a-f-]{36}' | head -1 || true
}

claude_newest_session() {
  local file
  file="$(ls -t "$(claude_project_dir "$1")"/*.jsonl 2>/dev/null | head -1 || true)"
  [ -n "$file" ] || return 0
  basename "$file" .jsonl
}

claude_config_dir() {
  echo "${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
}

claude_project_dir() {
  echo "$(claude_config_dir)/projects/$(sed 's/[^A-Za-z0-9]/-/g' <<< "$1")"
}
