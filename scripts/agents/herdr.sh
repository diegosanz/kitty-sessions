HERDR_DEFAULT_SESSION="default"

agent_label() {
  echo "herdr"
}

agent_binary() {
  echo "herdr"
}

agent_matches() {
  grep -qw "herdr" <<< "$1"
}

agent_discover_session() {
  local cmdline="$2" session
  session="$(herdr_session_from_cmdline "$cmdline")"
  echo "${session:-$HERDR_DEFAULT_SESSION}"
}

agent_session_name() {
  return 0
}

agent_resume() {
  if [ "$1" = "$HERDR_DEFAULT_SESSION" ]; then
    echo "herdr"
  else
    echo "herdr --session $1"
  fi
}

herdr_session_from_cmdline() {
  grep -oE -- '(--session[ =]|session attach )[^ ]+' <<< "$1" | grep -oE '[^ =]+$' | head -1 || true
}
