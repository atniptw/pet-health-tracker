#!/usr/bin/env bash
# Tests for scripts/spec-status.sh, run on fixture specs in a scratch directory.
set -euo pipefail
cd "$(dirname "$0")/.."
script="$PWD/scripts/spec-status.sh"

failures=0
fail() {
  echo "FAIL spec-status.sh: $1"
  failures=$((failures + 1))
}

dir=$(mktemp -d)
trap 'rm -rf "$dir"' EXIT
cd "$dir"
spec=specs/007-fixture
mkdir -p "$spec"

# Writes the fixture spec with Status $1.
status_line() { printf '# Feature Specification: Fixture\n\n**Status**: %s\n' "$1" >"$spec/spec.md"; }

# Writes the fixture tasks.md with the given task lines.
tasks() { printf '# Tasks: Fixture\n\n' >"$spec/tasks.md"; printf '%s\n' "$@" >>"$spec/tasks.md"; }

# Runs spec-status.sh with the given arguments; sets $status and $output.
run() {
  status=0
  output=$("$script" "$@" 2>&1) || status=$?
}

# Fails with message $1 unless the last run exited $2 with output holding $3.
expect() {
  [ "$status" = "$2" ] || fail "$1: exit $status, not $2 ($output)"
  [ -z "$3" ] || printf '%s\n' "$output" | grep -qF -- "$3" || fail "$1: no '$3' in: $output"
}

status_line Implemented
tasks '- [X] T001 One' '- [x] T002 Two'
run "$spec"
expect 'every task ticked, Implemented' 0 ''

status_line 'Being implemented'
run "$spec"
expect 'every task ticked, not Implemented' 1 "007-fixture: every task in tasks.md is ticked, so spec.md's Status should be Implemented, not Being implemented"

tasks '- [X] T001 One' '- [ ] T002 Two'
run "$spec"
expect 'a task open, Being implemented' 0 ''

status_line Implemented
run "$spec/"
expect 'a task open, Implemented' 1 "007-fixture: tasks.md has open tasks, so spec.md's Status shouldn't be Implemented"

rm "$spec/tasks.md"
run "$spec"
expect 'no tasks.md' 2 'spec-status.sh: no specs/007-fixture/tasks.md'

tasks '- [X] T001 One'
printf '# Feature Specification: Fixture\n' >"$spec/spec.md"
run "$spec"
expect 'no Status line' 2 'spec-status.sh: no **Status**: line in specs/007-fixture/spec.md'

printf '# Feature Specification: Fixture\n\n**Status**: Implemented\n**Status**: Draft\n' >"$spec/spec.md"
run "$spec"
expect 'two Status lines, the first Implemented' 0 ''

run specs/missing/
expect 'no spec.md, trailing slash' 2 'spec-status.sh: no specs/missing/spec.md'

run
expect 'no argument' 2 'usage: spec-status.sh <spec dir>'

run "$spec" "$spec"
expect 'two arguments' 2 'usage: spec-status.sh <spec dir>'

if [ "$failures" -gt 0 ]; then
  echo "$failures spec-status.sh test(s) failed"
  exit 1
fi
echo 'spec-status.sh tests passed'
