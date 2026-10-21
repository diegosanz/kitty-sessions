load test_helper

CLAUDE_ID="11111111-2222-3333-4444-555555555555"
OTHER_CLAUDE_ID="66666666-7777-8888-9999-000000000000"

@test "watch autosaves once the open sessions change" {
  claude_session_file "$BATS_TEST_TMPDIR" "$CLAUDE_ID" "mi sesión"
  write_ls < <(window_json 3 "$BATS_TEST_TMPDIR" "zsh" zsh)
  write_ls "$BATS_TEST_TMPDIR/after.json" < <(window_json 7 "$BATS_TEST_TMPDIR" "✳ Claude Code" claude)
  KITTEN_FAKE_LS_NEXT="$BATS_TEST_TMPDIR/after.json" KITTY_SESSIONS_ONCE=2 kitty-sessions watch
  run last_snapshot_rows
  [[ "$output" == "claude	$CLAUDE_ID	$BATS_TEST_TMPDIR	mi sesión	"* ]]
}

@test "watch does not overwrite the last snapshot with what it finds at startup" {
  printf 'claude\t%s\t%s\tmi sesión\t2026-01-01T00:00:00Z\n' "$CLAUDE_ID" "$BATS_TEST_TMPDIR" > "$BATS_TEST_TMPDIR/snap.tsv"
  mkdir -p "$KITTY_SESSIONS_DATA_DIR" && ln -s "$BATS_TEST_TMPDIR/snap.tsv" "$KITTY_SESSIONS_DATA_DIR/last"
  write_ls < <(window_json 3 "$HOME" "zsh" zsh)
  kitty-sessions watch
  run last_snapshot_rows
  [[ "$output" == "claude	$CLAUDE_ID"* ]]
}

@test "watch ignores changes in the window title of an agent" {
  claude_session_file "$BATS_TEST_TMPDIR" "$CLAUDE_ID"
  write_ls < <(window_json 7 "$BATS_TEST_TMPDIR" "◐ pensando" claude)
  write_ls "$BATS_TEST_TMPDIR/after.json" < <(window_json 7 "$BATS_TEST_TMPDIR" "◑ pensando" claude)
  KITTEN_FAKE_LS_NEXT="$BATS_TEST_TMPDIR/after.json" KITTY_SESSIONS_ONCE=2 kitty-sessions watch
  [ -z "$(ls "$KITTY_SESSIONS_DATA_DIR" 2>/dev/null | grep agents_)" ]
}

@test "watch rings the bell when claude finishes in a tab you are not looking at" {
  write_ls < <(window_json 7 "$BATS_TEST_TMPDIR" "◐ pensando" claude)
  write_ls "$BATS_TEST_TMPDIR/done.json" < <(window_json 7 "$BATS_TEST_TMPDIR" "✳ Claude Code" claude)
  KITTEN_FAKE_LS_NEXT="$BATS_TEST_TMPDIR/done.json" KITTY_SESSIONS_ONCE=2 kitty-sessions watch
  run tab_title_calls
  [ "$output" = "set-tab-title -m window_id:7 🔔 ✳ Claude Code" ]
}

@test "watch does not ring the bell when the tab is already active" {
  write_ls < <(window_json 7 "$BATS_TEST_TMPDIR" "◑ pensando" claude)
  write_active_ls "$BATS_TEST_TMPDIR/done.json" < <(window_json 7 "$BATS_TEST_TMPDIR" "✳ Claude Code" claude)
  KITTEN_FAKE_LS_NEXT="$BATS_TEST_TMPDIR/done.json" KITTY_SESSIONS_ONCE=2 kitty-sessions watch
  run tab_title_calls
  [ -z "$output" ]
}

@test "watch does not ring the bell for a claude that was already done at startup" {
  write_ls < <(window_json 7 "$BATS_TEST_TMPDIR" "✳ Claude Code" claude)
  KITTY_SESSIONS_ONCE=2 kitty-sessions watch
  run tab_title_calls
  [ -z "$output" ]
}

@test "watch clears the bell once you switch to the tab" {
  write_ls < <(window_json 7 "$BATS_TEST_TMPDIR" "◐ pensando" claude)
  write_ls "$BATS_TEST_TMPDIR/done.json" < <(window_json 7 "$BATS_TEST_TMPDIR" "✳ Claude Code" claude)
  write_active_ls "$BATS_TEST_TMPDIR/seen.json" < <(window_json 7 "$BATS_TEST_TMPDIR" "✳ Claude Code" claude)
  KITTEN_FAKE_LS_NEXT="$BATS_TEST_TMPDIR/done.json:$BATS_TEST_TMPDIR/seen.json" KITTY_SESSIONS_ONCE=3 kitty-sessions watch
  run tab_title_calls
  [ "${lines[0]}" = "set-tab-title -m window_id:7 🔔 ✳ Claude Code" ]
  [ "${lines[1]}" = "set-tab-title -m window_id:7 " ]
  [ "${#lines[@]}" -eq 2 ]
}

@test "watch clears the bell when claude goes back to work unseen" {
  write_ls < <(window_json 7 "$BATS_TEST_TMPDIR" "◐ pensando" claude)
  write_ls "$BATS_TEST_TMPDIR/done.json" < <(window_json 7 "$BATS_TEST_TMPDIR" "✳ Claude Code" claude)
  write_ls "$BATS_TEST_TMPDIR/again.json" < <(window_json 7 "$BATS_TEST_TMPDIR" "◑ pensando" claude)
  KITTEN_FAKE_LS_NEXT="$BATS_TEST_TMPDIR/done.json:$BATS_TEST_TMPDIR/again.json" KITTY_SESSIONS_ONCE=3 kitty-sessions watch
  run tab_title_calls
  [ "${lines[1]}" = "set-tab-title -m window_id:7 " ]
  [ "${#lines[@]}" -eq 2 ]
}

@test "watch follows title changes while the bell is showing" {
  write_ls < <(window_json 7 "$BATS_TEST_TMPDIR" "◐ pensando" claude)
  write_ls "$BATS_TEST_TMPDIR/done.json" < <(window_json 7 "$BATS_TEST_TMPDIR" "✳ Claude Code" claude)
  write_ls "$BATS_TEST_TMPDIR/renamed.json" < <(window_json 7 "$BATS_TEST_TMPDIR" "✳ mi sesión" claude)
  KITTEN_FAKE_LS_NEXT="$BATS_TEST_TMPDIR/done.json:$BATS_TEST_TMPDIR/renamed.json" KITTY_SESSIONS_ONCE=4 kitty-sessions watch
  run tab_title_calls
  [ "${lines[1]}" = "set-tab-title -m window_id:7 🔔 ✳ mi sesión" ]
  [ "${#lines[@]}" -eq 2 ]
}

@test "watch uses the bell icon from the environment" {
  write_ls < <(window_json 7 "$BATS_TEST_TMPDIR" "◐ pensando" claude)
  write_ls "$BATS_TEST_TMPDIR/done.json" < <(window_json 7 "$BATS_TEST_TMPDIR" "✳ Claude Code" claude)
  KITTY_SESSIONS_ICON_BELL="!" KITTEN_FAKE_LS_NEXT="$BATS_TEST_TMPDIR/done.json" KITTY_SESSIONS_ONCE=2 kitty-sessions watch
  run tab_title_calls
  [ "$output" = "set-tab-title -m window_id:7 ! ✳ Claude Code" ]
}

@test "watch leaves the tabs of opencode alone" {
  write_ls < <(window_json 8 "$BATS_TEST_TMPDIR" "◐ opencode" opencode)
  write_ls "$BATS_TEST_TMPDIR/done.json" < <(window_json 8 "$BATS_TEST_TMPDIR" "✳ opencode" opencode)
  KITTEN_FAKE_LS_NEXT="$BATS_TEST_TMPDIR/done.json" KITTY_SESSIONS_ONCE=2 kitty-sessions watch
  run tab_title_calls
  [ -z "$output" ]
}

@test "save takes the session id from the command line when present" {
  write_ls < <(window_json 7 "$BATS_TEST_TMPDIR" "✳ Claude Code" claude --session-id "$CLAUDE_ID")
  run kitty-sessions save
  [ "$output" = "Saved" ]
  run last_snapshot_rows
  [[ "$output" == "claude	$CLAUDE_ID	$BATS_TEST_TMPDIR	✳ Claude Code	"* ]]
}

@test "save detects agents launched through node wrappers" {
  write_ls < <(window_json 8 "$BATS_TEST_TMPDIR" "opencode" node /usr/lib/node_modules/opencode/bin/opencode)
  kitty-sessions save
  run last_snapshot_rows
  [[ "$output" == "opencode	ses_fake123	"* ]]
}

@test "save discovers the opencode session through its database" {
  write_ls < <(window_json 8 "$BATS_TEST_TMPDIR" "opencode" opencode)
  kitty-sessions save
  run last_snapshot_rows
  [[ "$output" == "opencode	ses_fake123	$BATS_TEST_TMPDIR	Sesión opencode	"* ]]
}

@test "save tells apart several claudes open in the same directory" {
  claude_session_file "$BATS_TEST_TMPDIR" "$CLAUDE_ID"
  claude_session_file "$BATS_TEST_TMPDIR" "$OTHER_CLAUDE_ID"
  claude_process_file 41 "$CLAUDE_ID" "$BATS_TEST_TMPDIR"
  claude_process_file 42 "$OTHER_CLAUDE_ID" "$BATS_TEST_TMPDIR"
  {
    WINDOW_PID=41 window_json 7 "$BATS_TEST_TMPDIR" "✳ Claude Code" claude
    WINDOW_PID=42 window_json 8 "$BATS_TEST_TMPDIR" "✳ Claude Code" claude
  } | write_ls
  kitty-sessions save
  run last_snapshot_rows
  [ "${#lines[@]}" -eq 2 ]
  [[ "${lines[0]}" == "claude	$CLAUDE_ID	"* ]]
  [[ "${lines[1]}" == "claude	$OTHER_CLAUDE_ID	"* ]]
}

@test "save skips agents whose session cannot be discovered" {
  write_ls < <(window_json 7 "$BATS_TEST_TMPDIR" "✳ Claude Code" claude)
  kitty-sessions save
  run last_snapshot_rows
  [ -z "$output" ]
}

@test "save records windows without an agent as shells" {
  write_ls < <(window_json 3 "$BATS_TEST_TMPDIR" "zsh" zsh)
  kitty-sessions save
  run last_snapshot_rows
  [[ "$output" == "shell	-	$BATS_TEST_TMPDIR	-	"* ]]
}

@test "save keeps the foreground command of a shell without running it" {
  write_ls < <(window_json 3 "$BATS_TEST_TMPDIR" "npm" npm run dev)
  kitty-sessions save
  run last_snapshot_rows
  [[ "$output" == "shell	-	$BATS_TEST_TMPDIR	npm run dev	"* ]]
}

@test "save ignores kitty's own dialogs such as the close confirmation" {
  write_ls < <(
    window_json 3 "$BATS_TEST_TMPDIR" "zsh" zsh
    window_json 4 "$BATS_TEST_TMPDIR" "Close OS window" /usr/bin/kitten ask --type=yesno --message "Are you sure?"
  )
  kitty-sessions save
  run last_snapshot_rows
  [ "${#lines[@]}" -eq 1 ]
  [[ "$output" == "shell	-	$BATS_TEST_TMPDIR	-	"* ]]
}

@test "autosave never writes an empty snapshot" {
  claude_session_file "$BATS_TEST_TMPDIR" "$CLAUDE_ID"
  write_ls < <(window_json 7 "$BATS_TEST_TMPDIR" "✳ Claude Code" claude)
  kitty-sessions save
  write_ls < /dev/null
  KITTY_SESSIONS_ONCE=2 kitty-sessions watch
  run last_snapshot_rows
  [[ "$output" == "claude	$CLAUDE_ID"* ]]
}

@test "autosave follows the working directory of shells" {
  write_ls < <(window_json 3 "$BATS_TEST_TMPDIR" "zsh" zsh)
  write_ls "$BATS_TEST_TMPDIR/after.json" < <(window_json 3 "$HOME" "zsh" zsh)
  KITTEN_FAKE_LS_NEXT="$BATS_TEST_TMPDIR/after.json" KITTY_SESSIONS_ONCE=2 kitty-sessions watch
  run last_snapshot_rows
  [[ "$output" == "shell	-	$HOME	-	"* ]]
}

@test "restore reopens saved sessions in new tabs" {
  printf 'claude\t%s\t%s\tmi sesión\t2026-01-01T00:00:00Z\n' "$CLAUDE_ID" "$BATS_TEST_TMPDIR" > "$BATS_TEST_TMPDIR/snap.tsv"
  mkdir -p "$KITTY_SESSIONS_DATA_DIR" && ln -s "$BATS_TEST_TMPDIR/snap.tsv" "$KITTY_SESSIONS_DATA_DIR/last"
  write_ls < <(window_json 3 "$BATS_TEST_TMPDIR" "zsh" zsh)
  run kitty-sessions restore
  [ "$output" = "Restored" ]
  grep -qxF "launch --type=tab --cwd $BATS_TEST_TMPDIR -- claude -r $CLAUDE_ID" "$KITTEN_FAKE_LOG"
}

@test "restore reopens saved shells in their directory" {
  printf 'shell\t-\t%s\t-\t2026-01-01T00:00:00Z\n' "$BATS_TEST_TMPDIR" > "$BATS_TEST_TMPDIR/snap.tsv"
  mkdir -p "$KITTY_SESSIONS_DATA_DIR" && ln -s "$BATS_TEST_TMPDIR/snap.tsv" "$KITTY_SESSIONS_DATA_DIR/last"
  write_ls < /dev/null
  run kitty-sessions restore
  [ "$output" = "Restored" ]
  grep -qxF "launch --type=tab --cwd $BATS_TEST_TMPDIR" "$KITTEN_FAKE_LOG"
  ! grep -q '^send-text' "$KITTEN_FAKE_LOG"
}

@test "restore types the saved command into the new shell without running it" {
  printf 'shell\t-\t%s\tnpm run dev\t2026-01-01T00:00:00Z\n' "$BATS_TEST_TMPDIR" > "$BATS_TEST_TMPDIR/snap.tsv"
  mkdir -p "$KITTY_SESSIONS_DATA_DIR" && ln -s "$BATS_TEST_TMPDIR/snap.tsv" "$KITTY_SESSIONS_DATA_DIR/last"
  write_ls < /dev/null
  KITTEN_FAKE_LAUNCH_ID=42 kitty-sessions restore
  grep -qxF "send-text -m id:42 npm run dev" "$KITTEN_FAKE_LOG"
}

@test "restore skips shells whose directory already has one open" {
  printf 'shell\t-\t%s\t-\t2026-01-01T00:00:00Z\n' "$BATS_TEST_TMPDIR" > "$BATS_TEST_TMPDIR/snap.tsv"
  mkdir -p "$KITTY_SESSIONS_DATA_DIR" && ln -s "$BATS_TEST_TMPDIR/snap.tsv" "$KITTY_SESSIONS_DATA_DIR/last"
  write_ls < <(window_json 3 "$BATS_TEST_TMPDIR" "zsh" zsh)
  kitty-sessions restore
  ! grep -q '^launch' "$KITTEN_FAKE_LOG"
}

@test "restore does not treat an agent window as an open shell" {
  printf 'shell\t-\t%s\t-\t2026-01-01T00:00:00Z\n' "$BATS_TEST_TMPDIR" > "$BATS_TEST_TMPDIR/snap.tsv"
  mkdir -p "$KITTY_SESSIONS_DATA_DIR" && ln -s "$BATS_TEST_TMPDIR/snap.tsv" "$KITTY_SESSIONS_DATA_DIR/last"
  write_ls < <(window_json 7 "$BATS_TEST_TMPDIR" "✳ Claude Code" claude)
  kitty-sessions restore
  grep -qxF "launch --type=tab --cwd $BATS_TEST_TMPDIR" "$KITTEN_FAKE_LOG"
}

@test "restore skips sessions that are already open" {
  printf 'claude\t%s\t%s\tmi sesión\t2026-01-01T00:00:00Z\n' "$CLAUDE_ID" "$BATS_TEST_TMPDIR" > "$BATS_TEST_TMPDIR/snap.tsv"
  mkdir -p "$KITTY_SESSIONS_DATA_DIR" && ln -s "$BATS_TEST_TMPDIR/snap.tsv" "$KITTY_SESSIONS_DATA_DIR/last"
  write_ls < <(window_json 7 "$BATS_TEST_TMPDIR" "✳ Claude Code" claude -r "$CLAUDE_ID")
  run kitty-sessions restore
  [ "$output" = "Restored" ]
  ! grep -q '^launch' "$KITTEN_FAKE_LOG"
}

@test "restore skips missing directories and missing agents" {
  printf 'claude\t%s\t%s/gone\tx\t2026-01-01T00:00:00Z\nunknown\tabc\t%s\ty\t2026-01-01T00:00:00Z\n' "$CLAUDE_ID" "$BATS_TEST_TMPDIR" "$BATS_TEST_TMPDIR" > "$BATS_TEST_TMPDIR/snap.tsv"
  mkdir -p "$KITTY_SESSIONS_DATA_DIR" && ln -s "$BATS_TEST_TMPDIR/snap.tsv" "$KITTY_SESSIONS_DATA_DIR/last"
  write_ls < <(window_json 3 "$BATS_TEST_TMPDIR" "zsh" zsh)
  run kitty-sessions restore
  [ "$output" = "Restored" ]
  ! grep -q '^launch' "$KITTEN_FAKE_LOG"
}

@test "restore without a snapshot does nothing" {
  run kitty-sessions restore
  [ "$output" = "nothing to restore" ]
}

@test "a second watcher for the same kitty exits immediately" {
  export KITTY_PID="$$"
  mkdir -p "$KITTY_SESSIONS_DATA_DIR"
  echo "$$" > "$KITTY_SESSIONS_DATA_DIR/watch-$$.lock"
  write_ls < <(window_json 7 "$BATS_TEST_TMPDIR" "✳ Claude Code" claude)
  run kitty-sessions watch
  [ "$status" -eq 0 ]
  ! grep -q '^ls' "$KITTEN_FAKE_LOG"
}

@test "watch removes lock files of dead watchers" {
  export KITTY_PID="$$"
  mkdir -p "$KITTY_SESSIONS_DATA_DIR"
  echo "999999999" > "$KITTY_SESSIONS_DATA_DIR/watch-12345.lock"
  write_ls < <(window_json 3 "$BATS_TEST_TMPDIR" "zsh" zsh)
  kitty-sessions watch
  [ ! -f "$KITTY_SESSIONS_DATA_DIR/watch-12345.lock" ]
}

@test "save keeps only the newest snapshots" {
  mkdir -p "$KITTY_SESSIONS_DATA_DIR"
  for i in 1 2 3; do : > "$KITTY_SESSIONS_DATA_DIR/agents_2026010100000${i}000000000.tsv"; done
  write_ls < <(window_json 7 "$BATS_TEST_TMPDIR" "✳ Claude Code" claude --session-id "$CLAUDE_ID")
  KITTY_SESSIONS_HISTORY=2 kitty-sessions save
  run ls "$KITTY_SESSIONS_DATA_DIR"
  [[ "$output" != *"agents_20260101000001000000000.tsv"* ]]
  [[ "$output" != *"agents_20260101000002000000000.tsv"* ]]
  [[ "$output" == *"agents_20260101000003000000000.tsv"* ]]
  [ "$(ls "$KITTY_SESSIONS_DATA_DIR"/agents_*.tsv | wc -l)" -eq 2 ]
  [ -f "$KITTY_SESSIONS_DATA_DIR/last" ]
}


@test "save with a name writes a named session and leaves the last snapshot alone" {
  write_ls < <(window_json 7 "$BATS_TEST_TMPDIR" "✳ Claude Code" claude --session-id "$CLAUDE_ID")
  run kitty-sessions save trabajo
  [ "$output" = "Saved trabajo" ]
  [[ "$(cat "$KITTY_SESSIONS_DATA_DIR/sessions/trabajo.tsv")" == "claude	$CLAUDE_ID	$BATS_TEST_TMPDIR	✳ Claude Code	"* ]]
  [ ! -e "$KITTY_SESSIONS_DATA_DIR/last" ]
}

@test "save with a name overwrites the previous session of that name" {
  mkdir -p "$KITTY_SESSIONS_DATA_DIR/sessions"
  printf 'shell\t-\t%s\t-\t2026-01-01T00:00:00Z\n' "$HOME" > "$KITTY_SESSIONS_DATA_DIR/sessions/trabajo.tsv"
  write_ls < <(window_json 3 "$BATS_TEST_TMPDIR" "zsh" zsh)
  kitty-sessions save trabajo
  [[ "$(cat "$KITTY_SESSIONS_DATA_DIR/sessions/trabajo.tsv")" == "shell	-	$BATS_TEST_TMPDIR	-	"* ]]
}

@test "save _auto behaves like save without a name" {
  write_ls < <(window_json 3 "$BATS_TEST_TMPDIR" "zsh" zsh)
  run kitty-sessions save _auto
  [ "$output" = "Saved" ]
  run last_snapshot_rows
  [[ "$output" == "shell	-	$BATS_TEST_TMPDIR	-	"* ]]
  [ ! -d "$KITTY_SESSIONS_DATA_DIR/sessions" ]
}

@test "save rejects names with characters other than letters, digits, - and _" {
  write_ls < <(window_json 3 "$BATS_TEST_TMPDIR" "zsh" zsh)
  run kitty-sessions save "mi sesion"
  [ "$status" -eq 1 ]
  run kitty-sessions save "../x"
  [ "$status" -eq 1 ]
  [ ! -d "$KITTY_SESSIONS_DATA_DIR/sessions" ]
}

@test "restore with a name reopens that session" {
  mkdir -p "$KITTY_SESSIONS_DATA_DIR/sessions"
  printf 'claude\t%s\t%s\tmi sesión\t2026-01-01T00:00:00Z\n' "$CLAUDE_ID" "$BATS_TEST_TMPDIR" > "$KITTY_SESSIONS_DATA_DIR/sessions/trabajo.tsv"
  write_ls < /dev/null
  run kitty-sessions restore trabajo
  [ "$output" = "Restored" ]
  grep -qxF "launch --type=tab --cwd $BATS_TEST_TMPDIR -- claude -r $CLAUDE_ID" "$KITTEN_FAKE_LOG"
}

@test "restore with an unknown name fails" {
  run kitty-sessions restore nada
  [ "$status" -eq 1 ]
  [[ "$output" == *"no session named nada"* ]]
}

@test "list shows _auto and the named sessions" {
  printf 'shell\t-\t%s\t-\t2026-01-01T00:00:00Z\n' "$HOME" > "$BATS_TEST_TMPDIR/snap.tsv"
  mkdir -p "$KITTY_SESSIONS_DATA_DIR/sessions" && ln -s "$BATS_TEST_TMPDIR/snap.tsv" "$KITTY_SESSIONS_DATA_DIR/last"
  printf 'claude\t%s\t%s\tx\t2026-02-02T00:00:00Z\nshell\t-\t%s\t-\t2026-02-02T00:00:00Z\n' "$CLAUDE_ID" "$HOME" "$HOME" > "$KITTY_SESSIONS_DATA_DIR/sessions/trabajo.tsv"
  run kitty-sessions list
  [ "${lines[0]}" = "_auto	2026-01-01T00:00:00Z	1 windows" ]
  [ "${lines[1]}" = "trabajo	2026-02-02T00:00:00Z	2 windows" ]
}

@test "delete removes a named session" {
  mkdir -p "$KITTY_SESSIONS_DATA_DIR/sessions"
  : > "$KITTY_SESSIONS_DATA_DIR/sessions/trabajo.tsv"
  run kitty-sessions delete trabajo
  [ "$output" = "Deleted trabajo" ]
  [ ! -e "$KITTY_SESSIONS_DATA_DIR/sessions/trabajo.tsv" ]
}

@test "delete fails for _auto and for unknown names" {
  run kitty-sessions delete _auto
  [ "$status" -eq 1 ]
  run kitty-sessions delete nada
  [ "$status" -eq 1 ]
}

@test "pruning old snapshots never touches named sessions" {
  mkdir -p "$KITTY_SESSIONS_DATA_DIR/sessions"
  for i in 1 2 3; do : > "$KITTY_SESSIONS_DATA_DIR/agents_2026010100000${i}000000000.tsv"; done
  : > "$KITTY_SESSIONS_DATA_DIR/sessions/trabajo.tsv"
  write_ls < <(window_json 3 "$BATS_TEST_TMPDIR" "zsh" zsh)
  KITTY_SESSIONS_HISTORY=1 kitty-sessions save
  [ -f "$KITTY_SESSIONS_DATA_DIR/sessions/trabajo.tsv" ]
}
