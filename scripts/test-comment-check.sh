#!/usr/bin/env bash
# Tests for scripts/comment-check.sh, run in a scratch git repo.
set -euo pipefail
cd "$(dirname "$0")/.."
script="$PWD/scripts/comment-check.sh"

failures=0
fail() {
  echo "FAIL comment-check.sh: $1"
  failures=$((failures + 1))
}

# check.sh runs from the pre-push hook, where git exports these. Left set, they
# would point the scratch repo's git commands at the real repository.
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_ALTERNATE_OBJECT_DIRECTORIES GIT_COMMON_DIR GIT_PREFIX

repo=$(mktemp -d)
trap 'rm -rf "$repo"' EXIT
cd "$repo"
git init -q
mkdir -p lib scripts .github/workflows .githooks .claude/hooks

# Each case writes one tracked file, then expects the check to pass or fail.
check_file() {
  local want=$1 label=$2 path=$3 content=$4 got=0
  printf '%s\n' "$content" >"$path"
  git add "$path"
  "$script" >/dev/null 2>&1 || got=$?
  [ "$got" = "$want" ] || fail "$label: expected exit $want, got $got"
  git rm -q --cached "$path" && rm "$path"
}
flags() { check_file 1 "$@"; }
passes() { check_file 0 "$@"; }

passes 'no comments' lib/a.dart 'void a() {}'
passes 'a timeless comment' lib/a.dart '// The old owner stays an admin.'

flags 'a Dart line comment' lib/a.dart '// Saved locally for now.'
flags 'a Dart doc comment' lib/a.dart '/// Previously this was a list.'
flags 'a trailing comment' lib/a.dart 'final x = 1; // eventually configurable'
flags 'any case' lib/a.dart '// FOR NOW, skip it.'
flags 'a version tag' lib/a.dart '// Ships in v2.'
flags 'a phase' lib/a.dart '// Done in phase 2.'
flags 'two words apart' lib/a.dart '// Not needed any more.'
flags 'a TODO for later' lib/a.dart '// TODO later: retry.'
flags 'a shell comment' scripts/a.sh '# Skipped for the time being.'
flags 'a rules comment' firestore.rules '// In the future, check roles.'
flags 'a JavaScript comment' lib/a.js '// Not used anymore.'
flags 'a workflow comment' .github/workflows/a.yml '# Later on, add iOS.'
flags 'a trailing shell comment' scripts/a.sh 'x=1 # eventually configurable'
flags 'a git hook comment' .githooks/pre-push '# Skipped for now.'
flags 'a Claude hook comment' .claude/hooks/a '# Skipped for now.'

passes 'a phrase in code, not a comment' lib/a.dart "const label = 'for now';"
passes 'a URL is not a comment' lib/a.dart "const url = 'https://x.dev/for now';"
passes 'a shebang' scripts/a.sh '#!/opt/v2/bin/bash'
passes 'the start of a longer word' lib/a.dart '// Fill the anymoreish list. Uses v2x and phase2.'
passes 'the end of a longer word' lib/a.dart '// Uses IPv4 and is reeventually fine.'

printf '%s\n' 'void a() {}' '// Saved for now.' >lib/a.dart
git add lib/a.dart
message=$("$script" 2>&1 >/dev/null || true)
[ "$message" = 'lib/a.dart:2: "for now" in a comment only makes sense when it was written.' ] ||
  fail "the message names the file, line and phrase: got '$message'"
git rm -q --cached lib/a.dart && rm lib/a.dart
passes 'an untracked file type' lib/a.md '# Done for now.'

printf 'lib/a.dart for now\n' >scripts/comment-allowlist.txt
git add scripts/comment-allowlist.txt
passes 'a phrase the allowlist allows in that file' lib/a.dart '// Kept as-is FOR NOW, by design.'
flags 'a phrase the allowlist allows only elsewhere' lib/b.dart '// Kept for now.'
flags 'a phrase the allowlist does not name' lib/a.dart '// Previously a map.'

# lib/firebase_options.dart is generated, so its comments are left alone.
passes 'the generated file' lib/firebase_options.dart '// Regenerate for now.'

# A file that can't be read is an error, not a pass.
printf 'void a() {}\n' >lib/locked.dart
git add lib/locked.dart
chmod 000 lib/locked.dart
"$script" >/dev/null 2>&1 && fail 'an unreadable file: expected an error'
chmod 644 lib/locked.dart

if [ "$failures" -gt 0 ]; then
  echo "$failures comment-check test(s) failed"
  exit 1
fi
echo 'comment-check tests passed'
