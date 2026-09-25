load test_helper

CLAUDE_ID="11111111-2222-3333-4444-555555555555"

@test "watch prefixes the tab title with the working icon" {
  write_ls < <(window_json 7 "$BATS_TEST_TMPDIR" "✳ Claude Code" claude)
  screen 7 "Thinking… (esc to interrupt)"
  run kitty-agents watch
  [ "$status" -eq 0 ]
  grep -qxF 'set-tab-title -m id:7 ⚙ ✳ Claude Code' "$KITTEN_FAKE_LOG"
}

@test "watch uses the attention icon on permission prompts" {
  write_ls < <(window_json 7 "$BATS_TEST_TMPDIR" "✳ Claude Code" claude)
  screen 7 "Do you want to proceed? ❯ 1. Yes"
  kitty-agents watch
  grep -qxF 'set-tab-title -m id:7 🔔 ✳ Claude Code' "$KITTEN_FAKE_LOG"
}

@test "watch uses the done icon on an idle prompt" {
  write_ls < <(window_json 7 "$BATS_TEST_TMPDIR" "✳ Claude Code" claude)
  screen 7 "❯  Try \"fix lint errors\""
  kitty-agents watch
  grep -qxF 'set-tab-title -m id:7 ✅ ✳ Claude Code' "$KITTEN_FAKE_LOG"
}

@test "icons are configurable through the environment" {
  write_ls < <(window_json 7 "$BATS_TEST_TMPDIR" "✳ Claude Code" claude)
  screen 7 "esc to interrupt"
  KITTY_AGENTS_ICON_WORKING="W" kitty-agents watch
  grep -qxF 'set-tab-title -m id:7 W ✳ Claude Code' "$KITTEN_FAKE_LOG"
}

@test "watch leaves windows without an agent alone" {
  write_ls < <(window_json 3 "$BATS_TEST_TMPDIR" "zsh" zsh)
  kitty-agents watch
  ! grep -q 'set-tab-title' "$KITTEN_FAKE_LOG"
}

@test "watch detects agents launched through node wrappers" {
  write_ls < <(window_json 7 "$BATS_TEST_TMPDIR" "opencode" node /usr/lib/node_modules/opencode/bin/opencode)
  screen 7 "esc interrupt"
  kitty-agents watch
  grep -qxF 'set-tab-title -m id:7 ⚙ opencode' "$KITTEN_FAKE_LOG"
}

@test "watch autosaves the open sessions" {
  claude_session_file "$BATS_TEST_TMPDIR" "$CLAUDE_ID" "mi sesión"
  write_ls < <(window_json 7 "$BATS_TEST_TMPDIR" "✳ Claude Code" claude)
  screen 7 "❯"
  kitty-agents watch
  run last_snapshot_rows
  [[ "$output" == "claude	$CLAUDE_ID	$BATS_TEST_TMPDIR	mi sesión	"* ]]
}

@test "save takes the session id from the command line when present" {
  write_ls < <(window_json 7 "$BATS_TEST_TMPDIR" "✳ Claude Code" claude --session-id "$CLAUDE_ID")
  run kitty-agents save
  [ "$output" = "saved 1 agent session(s)" ]
  run last_snapshot_rows
  [[ "$output" == "claude	$CLAUDE_ID	$BATS_TEST_TMPDIR	✳ Claude Code	"* ]]
}

@test "save discovers the opencode session through its database" {
  write_ls < <(window_json 8 "$BATS_TEST_TMPDIR" "opencode" opencode)
  kitty-agents save
  run last_snapshot_rows
  [[ "$output" == "opencode	ses_fake123	$BATS_TEST_TMPDIR	Sesión opencode	"* ]]
}

@test "save skips agents whose session cannot be discovered" {
  write_ls < <(window_json 7 "$BATS_TEST_TMPDIR" "✳ Claude Code" claude)
  run kitty-agents save
  [ "$output" = "saved 0 agent session(s)" ]
}

@test "autosave never writes an empty snapshot" {
  claude_session_file "$BATS_TEST_TMPDIR" "$CLAUDE_ID"
  write_ls < <(window_json 7 "$BATS_TEST_TMPDIR" "✳ Claude Code" claude)
  kitty-agents watch
  write_ls < <(window_json 3 "$BATS_TEST_TMPDIR" "zsh" zsh)
  kitty-agents watch
  run last_snapshot_rows
  [[ "$output" == "claude	$CLAUDE_ID"* ]]
}

@test "restore reopens saved sessions in new tabs" {
  printf 'claude\t%s\t%s\tmi sesión\t2026-01-01T00:00:00Z\n' "$CLAUDE_ID" "$BATS_TEST_TMPDIR" > "$BATS_TEST_TMPDIR/snap.tsv"
  mkdir -p "$KITTY_AGENTS_DATA_DIR" && ln -s "$BATS_TEST_TMPDIR/snap.tsv" "$KITTY_AGENTS_DATA_DIR/last"
  write_ls < <(window_json 3 "$BATS_TEST_TMPDIR" "zsh" zsh)
  run kitty-agents restore
  [ "$output" = "restored 1 agent session(s)" ]
  grep -qxF "launch --type=tab --cwd $BATS_TEST_TMPDIR -- claude -r $CLAUDE_ID" "$KITTEN_FAKE_LOG"
}

@test "restore skips sessions that are already open" {
  printf 'claude\t%s\t%s\tmi sesión\t2026-01-01T00:00:00Z\n' "$CLAUDE_ID" "$BATS_TEST_TMPDIR" > "$BATS_TEST_TMPDIR/snap.tsv"
  mkdir -p "$KITTY_AGENTS_DATA_DIR" && ln -s "$BATS_TEST_TMPDIR/snap.tsv" "$KITTY_AGENTS_DATA_DIR/last"
  write_ls < <(window_json 7 "$BATS_TEST_TMPDIR" "✳ Claude Code" claude -r "$CLAUDE_ID")
  run kitty-agents restore
  [ "${lines[-1]}" = "restored 0 agent session(s), 1 already open" ]
  ! grep -q '^launch' "$KITTEN_FAKE_LOG"
}

@test "restore skips missing directories and missing agents" {
  printf 'claude\t%s\t%s/gone\tx\t2026-01-01T00:00:00Z\nunknown\tabc\t%s\ty\t2026-01-01T00:00:00Z\n' "$CLAUDE_ID" "$BATS_TEST_TMPDIR" "$BATS_TEST_TMPDIR" > "$BATS_TEST_TMPDIR/snap.tsv"
  mkdir -p "$KITTY_AGENTS_DATA_DIR" && ln -s "$BATS_TEST_TMPDIR/snap.tsv" "$KITTY_AGENTS_DATA_DIR/last"
  write_ls < <(window_json 3 "$BATS_TEST_TMPDIR" "zsh" zsh)
  run kitty-agents restore
  [ "${lines[-1]}" = "restored 0 agent session(s), 1 with missing directory, 1 with agent not installed" ]
}

@test "restore without a snapshot does nothing" {
  run kitty-agents restore
  [ "$output" = "nothing to restore" ]
}

@test "status reports the agent and state of a window" {
  write_ls < <(window_json 7 "$BATS_TEST_TMPDIR" "✳ Claude Code" claude)
  screen 7 "esc to interrupt"
  run kitty-agents status 7
  [ "$output" = "claude working" ]
}

@test "a second watcher for the same kitty exits immediately" {
  export KITTY_PID="$$"
  mkdir -p "$KITTY_AGENTS_DATA_DIR"
  echo "$$" > "$KITTY_AGENTS_DATA_DIR/watch-$$.lock"
  write_ls < <(window_json 7 "$BATS_TEST_TMPDIR" "✳ Claude Code" claude)
  run kitty-agents watch
  [ "$status" -eq 0 ]
  ! grep -q 'set-tab-title' "$KITTEN_FAKE_LOG"
}

@test "watch resets the tab title once the agent exits" {
  write_ls < <(window_json 7 "$BATS_TEST_TMPDIR" "✳ Claude Code" claude)
  screen 7 "❯"
  write_ls "$BATS_TEST_TMPDIR/after.json" < <(window_json 7 "$BATS_TEST_TMPDIR" "zsh" zsh)
  KITTEN_FAKE_LS_NEXT="$BATS_TEST_TMPDIR/after.json" KITTY_AGENTS_ONCE=2 kitty-agents watch
  grep -qxF 'set-tab-title -m id:7 ' "$KITTEN_FAKE_LOG"
}
