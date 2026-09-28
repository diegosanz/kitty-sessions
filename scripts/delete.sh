#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/helpers.sh"

name="$1"

if is_auto_session "$name"; then
  echo "$AUTO_SESSION is managed by watch and cannot be deleted" >&2
  exit 1
fi
require_valid_session_name "$name"

file="$(named_session_file "$name")"
if [ ! -f "$file" ]; then
  echo "no session named $name" >&2
  exit 1
fi
rm -f "$file"
echo "Deleted $name"
