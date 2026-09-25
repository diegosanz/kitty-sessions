agent_label() {
  echo "opencode"
}

agent_binary() {
  echo "opencode"
}

agent_matches() {
  grep -qw "opencode" <<< "$1"
}

agent_discover_session() {
  local cwd="$1" cmdline="$2" id
  id="$(opencode_session_from_cmdline "$cmdline")"
  if [ -n "$id" ]; then
    echo "$id"
    return 0
  fi
  opencode_query "select id from session where directory = '$(opencode_sql_escape "$cwd")' and parent_id is null order by time_updated desc limit 1"
}

agent_session_name() {
  opencode_query "select title from session where id = '$(opencode_sql_escape "$1")'"
}

agent_resume() {
  printf 'opencode -s %q' "$1"
}

agent_status_from_screen() {
  local screen="$1"
  if grep -qiE "esc interrupt|esc to interrupt|working\.\.\.|thinking" <<< "$screen"; then
    echo "working"
  elif grep -qiE "permission|allow once|allow always|reject" <<< "$screen"; then
    echo "attention"
  elif grep -qiE "ctrl\+p|ctrl\+x|commands|enter send" <<< "$screen"; then
    echo "done"
  fi
}

opencode_session_from_cmdline() {
  grep -oE -- '(--session|-s)[ =]ses_[A-Za-z0-9]+' <<< "$1" | grep -oE 'ses_[A-Za-z0-9]+' | head -1 || true
}

opencode_query() {
  opencode db --format tsv "$1" 2>/dev/null | tail -n +2 | head -1 || true
}

opencode_sql_escape() {
  sed "s/'/''/g" <<< "$1"
}
