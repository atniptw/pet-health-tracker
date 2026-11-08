#!/usr/bin/env bash
# Tests for .githooks/pre-push, run in a scratch git repo with a worktree.
set -euo pipefail
cd "$(dirname "$0")/.."
hook="$PWD/.githooks/pre-push"

failures=0
fail() {
  echo "FAIL pre-push: $1"
  failures=$((failures + 1))
}

unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_ALTERNATE_OBJECT_DIRECTORIES GIT_COMMON_DIR GIT_PREFIX

scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT
git init -q "$scratch/repo"
git -C "$scratch/repo" config user.email test@example.com
git -C "$scratch/repo" config user.name test
git -C "$scratch/repo" commit -q --allow-empty -m init
git -C "$scratch/repo" worktree add -q "$scratch/wt"

# A stand-in check.sh that reports the git variables it sees and exits with
# the status in CHECK_STATUS.
mkdir "$scratch/wt/scripts"
cat > "$scratch/wt/scripts/check.sh" <<'EOF'
#!/usr/bin/env bash
echo "GIT_DIR=${GIT_DIR-unset} GIT_WORK_TREE=${GIT_WORK_TREE-unset}"
exit "${CHECK_STATUS:-0}"
EOF
chmod +x "$scratch/wt/scripts/check.sh"

# Git runs the pre-push hook from the worktree with GIT_DIR set to its
# absolute git directory, which tools like flutter then read as their own.
gitdir=$(git -C "$scratch/wt" rev-parse --absolute-git-dir)
run_hook() {
  (cd "$scratch/wt" && GIT_DIR="$gitdir" GIT_WORK_TREE="$scratch/wt" "$@" "$hook" origin url </dev/null)
}

out=$(run_hook env) || fail "check.sh passing should let the push through"
[ "$out" = 'GIT_DIR=unset GIT_WORK_TREE=unset' ] || fail "check.sh saw git variables: $out"

if run_hook env CHECK_STATUS=3 >/dev/null; then
  fail "check.sh failing should block the push"
fi

if [ "$failures" -gt 0 ]; then
  echo "$failures pre-push test(s) failed"
  exit 1
fi
echo 'pre-push tests passed'
