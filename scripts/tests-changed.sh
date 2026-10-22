#!/usr/bin/env bash
# Fails when a commit changes lib/ without changing test/ or integration_test/,
# unless its subject is a refactor ("refactor:" or "refactor(scope):").
# Checks the commits in <from>..<to>, by default the ones not yet on
# origin/main.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

if [ "$#" -eq 2 ]; then
  from=$1 to=$2
elif [ "$#" -eq 0 ]; then
  from=origin/main to=HEAD
else
  echo "usage: $0 [<from> <to>]" >&2
  exit 2
fi
for revision in "$from" "$to"; do
  if ! git rev-parse -q --verify "$revision^{commit}" >/dev/null; then
    echo "$revision is not a commit here, so there is nothing to compare with." >&2
    exit 1
  fi
done

found=0
for commit in $(git rev-list --no-merges "$from..$to"); do
  changed() { git diff-tree --no-commit-id --name-only -r "$commit" -- "$@"; }
  [ -n "$(changed lib ':(exclude)lib/firebase_options.dart')" ] || continue
  [ -z "$(changed test integration_test)" ] || continue
  git log -1 --format=%s "$commit" | grep -Eq '^refactor(\([^)]*\))?!?:' && continue
  echo "$(git log -1 --format='%h %s' "$commit"): changes lib/ but no tests." >&2
  found=1
done
exit "$found"
