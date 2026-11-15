#!/usr/bin/env bash
# Tests for the git hooks in .githooks, run in a scratch repo with a fake
# scripts/check.sh that records the git variables naming a repo that it was
# started with.
set -euo pipefail
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_ALTERNATE_OBJECT_DIRECTORIES GIT_COMMON_DIR GIT_PREFIX
cd "$(dirname "$0")/.."
hook="$PWD/.githooks/pre-push"

failures=0
fail() {
  echo "FAIL githooks: $1"
  failures=$((failures + 1))
}

dir=$(mktemp -d)
trap 'rm -rf "$dir"' EXIT
repo="$dir/repo"
git init -q "$repo"
mkdir -p "$repo/scripts" "$repo/sub"
cat >"$repo/scripts/check.sh" <<'FAKE'
#!/usr/bin/env bash
env | grep -E '^GIT_(DIR|WORK_TREE|INDEX_FILE|OBJECT_DIRECTORY|ALTERNATE_OBJECT_DIRECTORIES|COMMON_DIR|PREFIX)=' \
  >"$(dirname "$0")/../git-env" || true
exit "${FAKE_EXIT:-0}"
FAKE
chmod +x "$repo/scripts/check.sh"

# Runs the pre-push hook from $repo/sub as git runs it from a linked worktree,
# with GIT_DIR and the like set; sets $status.
run() {
  status=0
  (cd "$repo/sub" && FAKE_EXIT=$1 GIT_DIR="$repo/.git" GIT_WORK_TREE="$repo" GIT_INDEX_FILE="$repo/.git/index" \
    GIT_COMMON_DIR="$repo/.git" GIT_OBJECT_DIRECTORY="$repo/.git/objects" \
    GIT_ALTERNATE_OBJECT_DIRECTORIES="$repo/.git/objects" GIT_PREFIX=sub/ \
    "$hook" origin url </dev/null >/dev/null 2>&1) || status=$?
}

run 0
[ "$status" = 0 ] || fail "pre-push: passing checks, expected exit 0, got $status"
[ -e "$repo/git-env" ] || fail 'pre-push: expected it to run scripts/check.sh'
[ ! -s "$repo/git-env" ] || fail "pre-push: check.sh got git variables: $(tr '\n' ' ' <"$repo/git-env")"

run 1
[ "$status" = 1 ] || fail "pre-push: failing checks, expected exit 1, got $status"

if [ "$failures" -gt 0 ]; then
  echo "test-githooks.sh: $failures failed"
  exit 1
fi
echo 'test-githooks.sh: all passed'
