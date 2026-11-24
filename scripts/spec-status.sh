#!/usr/bin/env bash
# Checks that a spec's "**Status**:" line in spec.md matches its tasks.md: it
# says Implemented when every task is ticked, and not when a task is open.
# Exits 1 on a mismatch, and 2 on bad usage or a missing spec.md, tasks.md or
# Status line.
set -euo pipefail

[ $# = 1 ] || {
  echo 'usage: spec-status.sh <spec dir>' >&2
  exit 2
}
dir=${1%/}
name=$(basename "$dir")
for file in spec.md tasks.md; do
  [ -f "$dir/$file" ] || {
    echo "spec-status.sh: no $dir/$file" >&2
    exit 2
  }
done
status=$(sed -n 's/^\*\*Status\*\*: *//p' "$dir/spec.md" | head -1)
[ -n "$status" ] || {
  echo "spec-status.sh: no **Status**: line in $dir/spec.md" >&2
  exit 2
}

mismatch() {
  echo "$name: $1"
  exit 1
}
if grep -qE '^- \[ \] ' "$dir/tasks.md"; then
  [ "$status" != Implemented ] || mismatch "tasks.md has open tasks, so spec.md's Status shouldn't be Implemented"
else
  [ "$status" = Implemented ] || mismatch "every task in tasks.md is ticked, so spec.md's Status should be Implemented, not $status"
fi
