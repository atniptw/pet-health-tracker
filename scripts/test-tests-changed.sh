#!/usr/bin/env bash
# Tests for scripts/tests-changed.sh, run in a scratch git repo.
set -euo pipefail
cd "$(dirname "$0")/.."
script="$PWD/scripts/tests-changed.sh"

failures=0
fail() {
  echo "FAIL tests-changed.sh: $1"
  failures=$((failures + 1))
}

# check.sh runs from the pre-push hook, where git exports these. Left set, they
# would point the scratch repo's git commands at the real repository.
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_ALTERNATE_OBJECT_DIRECTORIES GIT_COMMON_DIR GIT_PREFIX

repo=$(mktemp -d)
trap 'rm -rf "$repo"' EXIT
cd "$repo"
git init -q
git config user.email test@example.com
git config user.name test
mkdir -p lib test integration_test docs
echo base >README.md && git add README.md && git commit -qm 'chore: start'

# Commits the given files (each gets a new line) with the given subject.
commit() {
  local subject=$1
  shift
  for path in "$@"; do echo "$RANDOM" >>"$path"; done
  git add "$@" && git commit -qm "$subject"
}

# Marks everything committed so far as already pushed.
pushed() { git update-ref refs/remotes/origin/main HEAD; }

expect() {
  local want=$1 label=$2 got=0
  shift 2
  "$script" "$@" >/dev/null 2>&1 || got=$?
  [ "$got" = "$want" ] || fail "$label: expected exit $want, got $got"
}

pushed
expect 0 'nothing to push'

commit 'feat: a' lib/a.dart test/a_test.dart
expect 0 'a lib change with a test change'
pushed

commit 'feat: b' lib/b.dart integration_test/b_test.dart
expect 0 'a lib change with an integration test change'
pushed

commit 'docs: c' docs/c.md
expect 0 'a change outside lib'
pushed

commit 'chore: regenerate' lib/firebase_options.dart
expect 0 'only the generated file'
pushed

commit 'refactor: d' lib/d.dart
expect 0 'a refactor'
pushed

commit 'refactor(pets)!: e' lib/e.dart
expect 0 'a scoped breaking refactor'
pushed

commit 'feat: f' lib/f.dart
expect 1 'a lib change without a test change'
message=$("$script" 2>&1 >/dev/null || true)
case "$message" in
  *"$(git rev-parse --short HEAD) feat: f"*) ;;
  *) fail "the message names the commit: got '$message'" ;;
esac
git reset -q --hard HEAD~1

commit 'refactoring: g' lib/g.dart
expect 1 'a subject that only starts like refactor'
git reset -q --hard HEAD~1

commit 'feat: h' lib/h.dart test/h_test.dart
commit 'fix: i' lib/i.dart
expect 1 'the second of two unpushed commits lacks tests'
expect 0 'a range that leaves it out' HEAD~2 HEAD~1
git reset -q --hard HEAD~2

commit 'fix: j' lib/j.dart
pushed
commit 'feat: k' lib/k.dart test/k_test.dart
expect 0 'a pushed commit is not checked again'
expect 1 'unless the range includes it' HEAD~2 HEAD

pushed
git checkout -q -b side
# The merge brings lib/m.dart onto main with no test change, so it would fail
# if merges were checked by their diff against the first parent.
commit 'refactor: m' lib/m.dart
git checkout -q -
commit 'docs: n' docs/n.md
git merge --no-ff -q -m 'Merge side' side
expect 0 'a merge commit is not checked'

expect 2 'one argument is a usage error' HEAD
expect 2 'three arguments are a usage error' a b c
expect 1 'a range that does not exist' no-such-commit HEAD
git update-ref -d refs/remotes/origin/main
expect 1 'no origin/main to compare with'

if [ "$failures" -gt 0 ]; then
  echo "$failures tests-changed test(s) failed"
  exit 1
fi
echo 'tests-changed tests passed'
