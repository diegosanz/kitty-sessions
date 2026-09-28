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

status_icon() {
  case "$1" in
    working) echo "${KITTY_AGENTS_ICON_WORKING-⚙}" ;;
    attention) echo "${KITTY_AGENTS_ICON_ATTENTION-🔔}" ;;
    done) echo "${KITTY_AGENTS_ICON_DONE-✅}" ;;
    *) echo "" ;;
  esac
}

set_tab_title() {
  kitten @ set-tab-title -m "id:$1" "$2" >/dev/null 2>&1 || true
}

set_tab_status() {
  local window_id="$1" status="$2" title="$3" icon
  icon="$(status_icon "$status")"
  if [ -n "$icon" ]; then
    set_tab_title "$window_id" "$icon $title"
  else
    set_tab_title "$window_id" "$title"
  fi
}

reset_tab_title() {
  set_tab_title "$1" ""
}

window_screen() {
  kitten @ get-text -m "id:$1" --extent screen 2>/dev/null || true
}

window_status() {
  local agent="$1" window_id="$2"
  load_agent "$agent" || return 1
  agent_status_from_screen "$(window_screen "$window_id")"
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

open_sessions() {
  local window_id cwd exes cmdlines title agent session_id
  while IFS=$'\t' read -r window_id cwd exes cmdlines title; do
    find_agent "$exes" || continue
    session_id="$(agent_discover_session "$cwd" "$cmdlines")"
    [ -n "$session_id" ] && echo "$session_id"
  done < <(kitten_ls)
}
