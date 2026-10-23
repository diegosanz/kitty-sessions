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
  echo "$EMPTY_FIELD"
}

agent_session_name() {
  return 0
}

agent_resume() {
  echo "opencode"
}
