#!/usr/bin/env bash
# SessionStart hook: when the checked-out branch's pull request has already
# merged, tells the session so before it trusts notes that say otherwise, and
# says how to get onto main. Prints nothing on main, on a detached HEAD, on a
# branch with no merged pull request, or when gh can't answer, and never stops
# the session from starting.
set -uo pipefail

cat >/dev/null
branch=$(git symbolic-ref --quiet --short HEAD 2>/dev/null) || exit 0
[ "$branch" = main ] && exit 0
number=$("${GH:-gh}" pr list --head "$branch" --state merged --limit 1 \
  --json number --jq '.[0].number // empty' 2>/dev/null) || exit 0
[ -n "$number" ] || exit 0
echo "Branch $branch's pull request #$number has already merged, so its work is on main." \
  "Before anything else: git checkout main && git pull --ff-only"
exit 0
