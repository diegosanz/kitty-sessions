#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/helpers.sh"

describe() {
  local name="$1" file="$2" windows saved_at
  windows="$(grep -c . "$file" || true)"
  saved_at="$(awk -F'\t' 'NR == 1 { print $5 }' "$file")"
  printf '%s\t%s\t%s windows\n' "$name" "${saved_at:-$EMPTY_FIELD}" "$windows"
}

last="$(last_snapshot)"
[ -f "$last" ] && describe "$AUTO_SESSION" "$last"

for file in "$(sessions_dir)"/*.tsv; do
  [ -f "$file" ] || continue
  describe "$(basename "${file%.tsv}")" "$file"
done
exit 0
