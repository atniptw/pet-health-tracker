#!/usr/bin/env bash
# Tests for scripts/fails-without-fix.sh, run in a scratch repository with a
# stand-in for flutter that reads the lib/ and test/ files it was run with.
set -euo pipefail
cd "$(dirname "$0")/.."
# check.sh runs from the pre-push hook, where git exports these. Left set, they
# would point the scratch repos' git commands at the real repository.
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_ALTERNATE_OBJECT_DIRECTORIES GIT_COMMON_DIR GIT_PREFIX

failures=0
fail() {
  echo "FAIL fails-without-fix.sh: $1"
  failures=$((failures + 1))
}

dir=$(mktemp -d)
trap 'rm -rf "$dir"' EXIT
repo="$dir/repo"
mkdir -p "$repo/scripts" "$repo/lib" "$repo/test"
cp scripts/test.sh scripts/fails-without-fix.sh "$repo/scripts/"
echo old >"$repo/lib/a.txt"
echo old >"$repo/test/a_test.txt"
git -C "$repo" init -q -b main
git -C "$repo" add .
git -C "$repo" -c user.name=t -c user.email=t@t commit -q -m init
echo fixed >"$repo/lib/a.txt"
echo new >"$repo/test/a_test.txt"
echo new >"$repo/test/b_test.txt"
mkdir -p "$repo/.dart_tool"
echo packages >"$repo/.dart_tool/package_config.json"

# The stand-in passes when FAKE is "pass", or when FAKE is "needs-fix" and
# lib/a.txt holds the fix. It records what it saw in $dir/seen.
cat >"$dir/flutter" <<'FLUTTER'
#!/usr/bin/env bash
seen="$(dirname "$0")/seen"
echo "lib=$(cat lib/a.txt) test=$(cat test/a_test.txt) b=$(cat test/b_test.txt 2>/dev/null)" \
  "packages=$(cat .dart_tool/package_config.json 2>/dev/null) args=$*" >"$seen"
case "$FAKE" in
  pass) exit 0 ;;
  needs-fix) [ "$(cat lib/a.txt)" = fixed ] ;;
esac
FLUTTER
chmod +x "$dir/flutter"

# Runs the script with the stand-in answering $1; sets $status and $output.
run() {
  local fake=$1
  shift
  status=0
  output=$(FLUTTER="$dir/flutter" FAKE=$fake "$repo/scripts/fails-without-fix.sh" "$@" 2>&1) || status=$?
}

run needs-fix test/a_test.txt test/b_test.txt
[ "$status" = 0 ] || fail "tests that need the fix: expected exit 0, got $status: $output"
case "$output" in *'fail with HEAD'*) ;; *) fail "tests that need the fix: expected it to say they fail with HEAD, got: $output" ;; esac
case "$(cat "$dir/seen")" in
  'lib=old test=new b=new packages=packages args='*'test/a_test.txt test/b_test.txt') ;;
  *) fail "expected HEAD's lib/ with the working tree's tests, package config and the given files, got: $(cat "$dir/seen")" ;;
esac
[ "$(cat "$repo/lib/a.txt")" = fixed ] || fail 'the working tree lost its fix'
[ -z "$(git -C "$repo" stash list)" ] || fail 'it stashed something'
[ "$(git -C "$repo" worktree list | wc -l | tr -d ' ')" = 1 ] || fail 'its worktree was left behind'

run pass test/a_test.txt
[ "$status" = 1 ] || fail "tests that pass without the fix: expected exit 1, got $status: $output"
case "$output" in *'pass with HEAD'*) ;; *) fail "tests that pass without the fix: expected it to say they pass with HEAD, got: $output" ;; esac
[ "$(git -C "$repo" worktree list | wc -l | tr -d ' ')" = 1 ] || fail 'its worktree was left behind after a failure'

run pass
[ "$status" = 2 ] || fail "no test files: expected exit 2, got $status"

# A repository with no commits has no HEAD to make the worktree from.
empty="$dir/empty"
mkdir -p "$empty/scripts" "$empty/test"
cp "$repo/scripts/test.sh" "$repo/scripts/fails-without-fix.sh" "$empty/scripts/"
git -C "$empty" init -q -b main
status=0
output=$(FLUTTER="$dir/flutter" FAKE=needs-fix "$empty/scripts/fails-without-fix.sh" test/a_test.txt 2>&1) || status=$?
[ "$status" = 2 ] || fail "no HEAD: expected exit 2, got $status: $output"
case "$output" in *'fail with HEAD'*) fail "no HEAD: said the tests fail with HEAD: $output" ;; esac

if [ "$failures" -gt 0 ]; then
  echo "$failures fails-without-fix test(s) failed"
  exit 1
fi
echo 'fails-without-fix tests passed'
