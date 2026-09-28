load test_helper

CLAUDE_ID="11111111-2222-3333-4444-555555555555"

@test "watch autosaves once the open sessions change" {
  claude_session_file "$BATS_TEST_TMPDIR" "$CLAUDE_ID" "mi sesión"
  write_ls < <(window_json 3 "$BATS_TEST_TMPDIR" "zsh" zsh)
  write_ls "$BATS_TEST_TMPDIR/after.json" < <(window_json 7 "$BATS_TEST_TMPDIR" "✳ Claude Code" claude)
  KITTEN_FAKE_LS_NEXT="$BATS_TEST_TMPDIR/after.json" KITTY_AGENTS_ONCE=2 kitty-agents watch
  run last_snapshot_rows
  [[ "$output" == "claude	$CLAUDE_ID	$BATS_TEST_TMPDIR	mi sesión	"* ]]
}

@test "watch does not overwrite the last snapshot with what it finds at startup" {
  printf 'claude\t%s\t%s\tmi sesión\t2026-01-01T00:00:00Z\n' "$CLAUDE_ID" "$BATS_TEST_TMPDIR" > "$BATS_TEST_TMPDIR/snap.tsv"
  mkdir -p "$KITTY_AGENTS_DATA_DIR" && ln -s "$BATS_TEST_TMPDIR/snap.tsv" "$KITTY_AGENTS_DATA_DIR/last"
  write_ls < <(window_json 3 "$HOME" "zsh" zsh)
  kitty-agents watch
  run last_snapshot_rows
  [[ "$output" == "claude	$CLAUDE_ID"* ]]
}

@test "watch ignores changes in the window title of an agent" {
  claude_session_file "$BATS_TEST_TMPDIR" "$CLAUDE_ID"
  write_ls < <(window_json 7 "$BATS_TEST_TMPDIR" "◐ pensando" claude)
  write_ls "$BATS_TEST_TMPDIR/after.json" < <(window_json 7 "$BATS_TEST_TMPDIR" "◑ pensando" claude)
  KITTEN_FAKE_LS_NEXT="$BATS_TEST_TMPDIR/after.json" KITTY_AGENTS_ONCE=2 kitty-agents watch
  [ -z "$(ls "$KITTY_AGENTS_DATA_DIR" 2>/dev/null | grep agents_)" ]
}

@test "save takes the session id from the command line when present" {
  write_ls < <(window_json 7 "$BATS_TEST_TMPDIR" "✳ Claude Code" claude --session-id "$CLAUDE_ID")
  run kitty-agents save
  [ "$output" = "Saved" ]
  run last_snapshot_rows
  [[ "$output" == "claude	$CLAUDE_ID	$BATS_TEST_TMPDIR	✳ Claude Code	"* ]]
}

@test "save detects agents launched through node wrappers" {
  write_ls < <(window_json 8 "$BATS_TEST_TMPDIR" "opencode" node /usr/lib/node_modules/opencode/bin/opencode)
  kitty-agents save
  run last_snapshot_rows
  [[ "$output" == "opencode	ses_fake123	"* ]]
}

@test "save discovers the opencode session through its database" {
  write_ls < <(window_json 8 "$BATS_TEST_TMPDIR" "opencode" opencode)
  kitty-agents save
  run last_snapshot_rows
  [[ "$output" == "opencode	ses_fake123	$BATS_TEST_TMPDIR	Sesión opencode	"* ]]
}

@test "save skips agents whose session cannot be discovered" {
  write_ls < <(window_json 7 "$BATS_TEST_TMPDIR" "✳ Claude Code" claude)
  kitty-agents save
  run last_snapshot_rows
  [ -z "$output" ]
}

@test "save records windows without an agent as shells" {
  write_ls < <(window_json 3 "$BATS_TEST_TMPDIR" "zsh" zsh)
  kitty-agents save
  run last_snapshot_rows
  [[ "$output" == "shell	-	$BATS_TEST_TMPDIR	-	"* ]]
}

@test "save keeps the foreground command of a shell without running it" {
  write_ls < <(window_json 3 "$BATS_TEST_TMPDIR" "npm" npm run dev)
  kitty-agents save
  run last_snapshot_rows
  [[ "$output" == "shell	-	$BATS_TEST_TMPDIR	npm run dev	"* ]]
}

@test "save ignores kitty's own dialogs such as the close confirmation" {
  write_ls < <(
    window_json 3 "$BATS_TEST_TMPDIR" "zsh" zsh
    window_json 4 "$BATS_TEST_TMPDIR" "Close OS window" /usr/bin/kitten ask --type=yesno --message "Are you sure?"
  )
  kitty-agents save
  run last_snapshot_rows
  [ "${#lines[@]}" -eq 1 ]
  [[ "$output" == "shell	-	$BATS_TEST_TMPDIR	-	"* ]]
}

@test "autosave never writes an empty snapshot" {
  claude_session_file "$BATS_TEST_TMPDIR" "$CLAUDE_ID"
  write_ls < <(window_json 7 "$BATS_TEST_TMPDIR" "✳ Claude Code" claude)
  kitty-agents save
  write_ls < /dev/null
  KITTY_AGENTS_ONCE=2 kitty-agents watch
  run last_snapshot_rows
  [[ "$output" == "claude	$CLAUDE_ID"* ]]
}

@test "autosave follows the working directory of shells" {
  write_ls < <(window_json 3 "$BATS_TEST_TMPDIR" "zsh" zsh)
  write_ls "$BATS_TEST_TMPDIR/after.json" < <(window_json 3 "$HOME" "zsh" zsh)
  KITTEN_FAKE_LS_NEXT="$BATS_TEST_TMPDIR/after.json" KITTY_AGENTS_ONCE=2 kitty-agents watch
  run last_snapshot_rows
  [[ "$output" == "shell	-	$HOME	-	"* ]]
}

@test "restore reopens saved sessions in new tabs" {
  printf 'claude\t%s\t%s\tmi sesión\t2026-01-01T00:00:00Z\n' "$CLAUDE_ID" "$BATS_TEST_TMPDIR" > "$BATS_TEST_TMPDIR/snap.tsv"
  mkdir -p "$KITTY_AGENTS_DATA_DIR" && ln -s "$BATS_TEST_TMPDIR/snap.tsv" "$KITTY_AGENTS_DATA_DIR/last"
  write_ls < <(window_json 3 "$BATS_TEST_TMPDIR" "zsh" zsh)
  run kitty-agents restore
  [ "$output" = "Restored" ]
  grep -qxF "launch --type=tab --cwd $BATS_TEST_TMPDIR -- claude -r $CLAUDE_ID" "$KITTEN_FAKE_LOG"
}

@test "restore reopens saved shells in their directory" {
  printf 'shell\t-\t%s\t-\t2026-01-01T00:00:00Z\n' "$BATS_TEST_TMPDIR" > "$BATS_TEST_TMPDIR/snap.tsv"
  mkdir -p "$KITTY_AGENTS_DATA_DIR" && ln -s "$BATS_TEST_TMPDIR/snap.tsv" "$KITTY_AGENTS_DATA_DIR/last"
  write_ls < /dev/null
  run kitty-agents restore
  [ "$output" = "Restored" ]
  grep -qxF "launch --type=tab --cwd $BATS_TEST_TMPDIR" "$KITTEN_FAKE_LOG"
  ! grep -q '^send-text' "$KITTEN_FAKE_LOG"
}

@test "restore types the saved command into the new shell without running it" {
  printf 'shell\t-\t%s\tnpm run dev\t2026-01-01T00:00:00Z\n' "$BATS_TEST_TMPDIR" > "$BATS_TEST_TMPDIR/snap.tsv"
  mkdir -p "$KITTY_AGENTS_DATA_DIR" && ln -s "$BATS_TEST_TMPDIR/snap.tsv" "$KITTY_AGENTS_DATA_DIR/last"
  write_ls < /dev/null
  KITTEN_FAKE_LAUNCH_ID=42 kitty-agents restore
  grep -qxF "send-text -m id:42 npm run dev" "$KITTEN_FAKE_LOG"
}

@test "restore skips shells whose directory already has one open" {
  printf 'shell\t-\t%s\t-\t2026-01-01T00:00:00Z\n' "$BATS_TEST_TMPDIR" > "$BATS_TEST_TMPDIR/snap.tsv"
  mkdir -p "$KITTY_AGENTS_DATA_DIR" && ln -s "$BATS_TEST_TMPDIR/snap.tsv" "$KITTY_AGENTS_DATA_DIR/last"
  write_ls < <(window_json 3 "$BATS_TEST_TMPDIR" "zsh" zsh)
  kitty-agents restore
  ! grep -q '^launch' "$KITTEN_FAKE_LOG"
}

@test "restore does not treat an agent window as an open shell" {
  printf 'shell\t-\t%s\t-\t2026-01-01T00:00:00Z\n' "$BATS_TEST_TMPDIR" > "$BATS_TEST_TMPDIR/snap.tsv"
  mkdir -p "$KITTY_AGENTS_DATA_DIR" && ln -s "$BATS_TEST_TMPDIR/snap.tsv" "$KITTY_AGENTS_DATA_DIR/last"
  write_ls < <(window_json 7 "$BATS_TEST_TMPDIR" "✳ Claude Code" claude)
  kitty-agents restore
  grep -qxF "launch --type=tab --cwd $BATS_TEST_TMPDIR" "$KITTEN_FAKE_LOG"
}

@test "restore skips sessions that are already open" {
  printf 'claude\t%s\t%s\tmi sesión\t2026-01-01T00:00:00Z\n' "$CLAUDE_ID" "$BATS_TEST_TMPDIR" > "$BATS_TEST_TMPDIR/snap.tsv"
  mkdir -p "$KITTY_AGENTS_DATA_DIR" && ln -s "$BATS_TEST_TMPDIR/snap.tsv" "$KITTY_AGENTS_DATA_DIR/last"
  write_ls < <(window_json 7 "$BATS_TEST_TMPDIR" "✳ Claude Code" claude -r "$CLAUDE_ID")
  run kitty-agents restore
  [ "$output" = "Restored" ]
  ! grep -q '^launch' "$KITTEN_FAKE_LOG"
}

@test "restore skips missing directories and missing agents" {
  printf 'claude\t%s\t%s/gone\tx\t2026-01-01T00:00:00Z\nunknown\tabc\t%s\ty\t2026-01-01T00:00:00Z\n' "$CLAUDE_ID" "$BATS_TEST_TMPDIR" "$BATS_TEST_TMPDIR" > "$BATS_TEST_TMPDIR/snap.tsv"
  mkdir -p "$KITTY_AGENTS_DATA_DIR" && ln -s "$BATS_TEST_TMPDIR/snap.tsv" "$KITTY_AGENTS_DATA_DIR/last"
  write_ls < <(window_json 3 "$BATS_TEST_TMPDIR" "zsh" zsh)
  run kitty-agents restore
  [ "$output" = "Restored" ]
  ! grep -q '^launch' "$KITTEN_FAKE_LOG"
}

@test "restore without a snapshot does nothing" {
  run kitty-agents restore
  [ "$output" = "nothing to restore" ]
}

@test "a second watcher for the same kitty exits immediately" {
  export KITTY_PID="$$"
  mkdir -p "$KITTY_AGENTS_DATA_DIR"
  echo "$$" > "$KITTY_AGENTS_DATA_DIR/watch-$$.lock"
  write_ls < <(window_json 7 "$BATS_TEST_TMPDIR" "✳ Claude Code" claude)
  run kitty-agents watch
  [ "$status" -eq 0 ]
  ! grep -q '^ls' "$KITTEN_FAKE_LOG"
}

@test "watch removes lock files of dead watchers" {
  export KITTY_PID="$$"
  mkdir -p "$KITTY_AGENTS_DATA_DIR"
  echo "999999999" > "$KITTY_AGENTS_DATA_DIR/watch-12345.lock"
  write_ls < <(window_json 3 "$BATS_TEST_TMPDIR" "zsh" zsh)
  kitty-agents watch
  [ ! -f "$KITTY_AGENTS_DATA_DIR/watch-12345.lock" ]
}

@test "save keeps only the newest snapshots" {
  mkdir -p "$KITTY_AGENTS_DATA_DIR"
  for i in 1 2 3; do : > "$KITTY_AGENTS_DATA_DIR/agents_2026010100000${i}000000000.tsv"; done
  write_ls < <(window_json 7 "$BATS_TEST_TMPDIR" "✳ Claude Code" claude --session-id "$CLAUDE_ID")
  KITTY_AGENTS_HISTORY=2 kitty-agents save
  run ls "$KITTY_AGENTS_DATA_DIR"
  [[ "$output" != *"agents_20260101000001000000000.tsv"* ]]
  [[ "$output" != *"agents_20260101000002000000000.tsv"* ]]
  [[ "$output" == *"agents_20260101000003000000000.tsv"* ]]
  [ "$(ls "$KITTY_AGENTS_DATA_DIR"/agents_*.tsv | wc -l)" -eq 2 ]
  [ -f "$KITTY_AGENTS_DATA_DIR/last" ]
}

