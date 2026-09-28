SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENTS_DIR="$SCRIPTS_DIR/agents"

data_dir() {
  echo "${KITTY_AGENTS_DATA_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/kitty-agents}"
}

last_snapshot() {
  echo "$(data_dir)/last"
}

poll_interval() {
  echo "${KITTY_AGENTS_INTERVAL:-1}"
}

snapshots_to_keep() {
  echo "${KITTY_AGENTS_HISTORY:-20}"
}

list_agents() {
  local file
  for file in "$AGENTS_DIR"/*.sh; do
    [ -f "$file" ] && basename "${file%.sh}"
  done
}

load_agent() {
  local file="$AGENTS_DIR/$1.sh"
  [ -f "$file" ] || return 1
  source "$file"
}

agent_available() {
  load_agent "$1" && command -v "$(agent_binary)" >/dev/null 2>&1
}

kitten_ls() {
  kitten @ ls 2>/dev/null | jq -r '
    def exe_name:
      (.cmdline // []) as $argv
      | ($argv[0] // "" | split("/") | last) as $first
      | if ($first == "node" or $first == "bun" or $first == "deno")
        then ($argv[1] // "" | split("/") | last)
        else $first end;
    .[].tabs[].windows[]
    | select(((.foreground_processes // [])[0] // {} | exe_name) != "kitten")
    | [
        .id,
        .cwd,
        ((.foreground_processes // []) | map(exe_name) | join(" ")),
        ((.foreground_processes // []) | map(.cmdline | join(" ")) | join(" || ")),
        .title
      ]
    | @tsv'
}

find_agent() {
  local exes="$1" candidate
  for candidate in $(list_agents); do
    load_agent "$candidate"
    if agent_matches "$exes"; then
      agent="$candidate"
      return 0
    fi
  done
  return 1
}

write_snapshot() {
  local rows="$1" dir snapshot
  dir="$(data_dir)"
  mkdir -p "$dir"
  snapshot="$dir/agents_$(date +%Y%m%dT%H%M%S%N).tsv"
  printf '%s' "$rows" > "$snapshot"
  ln -sfn "$(basename "$snapshot")" "$dir/last"
  prune_old_snapshots "$dir"
  echo "$snapshot"
}

prune_old_snapshots() {
  local dir="$1" old
  while read -r old; do
    [ -n "$old" ] && rm -f "$old"
  done < <(ls -1r "$dir"/agents_*.tsv 2>/dev/null | tail -n +"$(( $(snapshots_to_keep) + 1 ))")
}

SHELL_ROW="shell"
EMPTY_FIELD="-"

shell_names() {
  echo "zsh bash fish sh $(basename "${SHELL:-}")"
}

is_shell() {
  grep -qw -- "$1" <<< "$(shell_names)"
}

foreground_command() {
  local exes="$1" cmdlines="$2" first_exe
  first_exe="${exes%% *}"
  if [ -z "$first_exe" ] || is_shell "$first_exe"; then
    echo "$EMPTY_FIELD"
  else
    echo "${cmdlines%% || *}"
  fi
}

snapshot_row() {
  local cwd="$1" exes="$2" cmdlines="$3" title="$4" saved_at="$5" agent session_id name
  if ! find_agent "$exes"; then
    printf '%s\t%s\t%s\t%s\t%s\n' "$SHELL_ROW" "$EMPTY_FIELD" "$cwd" "$(foreground_command "$exes" "$cmdlines")" "$saved_at"
    return 0
  fi
  session_id="$(agent_discover_session "$cwd" "$cmdlines")"
  [ -n "$session_id" ] || return 0
  name="$(agent_session_name "$session_id" "$cwd")"
  [ -n "$name" ] || name="$title"
  [ -n "$name" ] || name="$EMPTY_FIELD"
  printf '%s\t%s\t%s\t%s\t%s\n' "$agent" "$session_id" "$cwd" "$name" "$saved_at"
}

snapshot_rows() {
  local window_id cwd exes cmdlines title saved_at
  saved_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  while IFS=$'\t' read -r window_id cwd exes cmdlines title; do
    [ -n "$window_id" ] || continue
    snapshot_row "$cwd" "$exes" "$cmdlines" "$title" "$saved_at"
  done <<< "$1"
}

snapshot_change_key() {
  awk -F'\t' -v OFS='\t' -v shell="$SHELL_ROW" '{ print $1, $2, $3, ($1 == shell ? $4 : "") }'
}

open_shell_cwds() {
  local window_id cwd exes cmdlines title
  while IFS=$'\t' read -r window_id cwd exes cmdlines title; do
    find_agent "$exes" && continue
    echo "$cwd"
  done < <(kitten_ls)
}

open_sessions() {
  local window_id cwd exes cmdlines title agent session_id
  while IFS=$'\t' read -r window_id cwd exes cmdlines title; do
    find_agent "$exes" || continue
    session_id="$(agent_discover_session "$cwd" "$cmdlines")"
    [ -n "$session_id" ] || continue
    echo "$session_id"
  done < <(kitten_ls)
}
