#!/usr/bin/env bash
# Runs the given test files against HEAD's lib/, to see that they fail without
# the change in the working tree. The tests come from the working tree's test/
# and everything else from HEAD, in a temporary worktree that is removed
# afterwards, so nothing in this checkout is stashed or changed. Passes when
# the tests fail there and fails when they pass; prints the failures so their
# reason can be checked against the spec.
set -uo pipefail
cd "$(dirname "$0")/.."

if [ "$#" = 0 ]; then
  echo 'usage: scripts/fails-without-fix.sh <test files>...' >&2
  exit 2
fi

scratch=$(mktemp -d)
tree="$scratch/head"
git worktree add -q --detach "$tree" HEAD || exit 2
trap 'git worktree remove --force "$tree"; rm -rf "$scratch"' EXIT
rm -rf "$tree/test"
cp -R test "$tree/test"
if [ -f .dart_tool/package_config.json ]; then
  mkdir -p "$tree/.dart_tool"
  cp .dart_tool/package_config.json "$tree/.dart_tool/"
fi

if (cd "$tree" && ./scripts/test.sh "$@"); then
  echo "FAIL: these tests pass with HEAD's lib/, so they don't test the change"
  exit 1
fi
echo "These tests fail with HEAD's lib/, as they should without the change."
