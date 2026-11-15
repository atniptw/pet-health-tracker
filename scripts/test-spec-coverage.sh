#!/usr/bin/env bash
# Tests for scripts/spec-coverage.sh, run on fixture specs and tests in a
# scratch directory.
set -euo pipefail
cd "$(dirname "$0")/.."
script="$PWD/scripts/spec-coverage.sh"

failures=0
fail() {
  echo "FAIL spec-coverage.sh: $1"
  failures=$((failures + 1))
}

dir=$(mktemp -d)
trap 'rm -rf "$dir"' EXIT
cd "$dir"
spec=specs/007-fixture
mkdir -p "$spec" specs/008-other test/domain integration_test
cat >"$spec/spec.md" <<'SPEC'
# Feature Specification: Fixture

### User Story 1 - First story (Priority: P1)

**Acceptance Scenarios**:

1. **Given** one pet, **When** they log, **Then** it is saved.
2. **Given** two pets, **When** they log, **Then** they pick one.

### User Story 2 - Second story (Priority: P2)

1. **Given** events, **When** they look, **Then** they see them.

### Edge Cases

- **EC-01**: A time in the future is refused.

## Requirements

1. A numbered line outside a story is not a scenario.

- **FR-001**: Caregivers MUST be able to add pets.
- **FR-002**: Logging MUST work offline.

## Success Criteria

- **SC-001**: Logging takes under 10 seconds.
SPEC
cp "$spec/spec.md" specs/008-other/spec.md

# Runs spec-coverage.sh with the given arguments; sets $status and $output.
run() {
  status=0
  output=$("$script" "$@" 2>&1) || status=$?
}

# Fails with message $1 unless $output has the line $2.
expect_line() {
  printf '%s\n' "$output" | grep -qxF -- "$2" || fail "$1: no line '$2' in: $output"
}

# Fails with message $1 if $output has a line containing $2.
expect_no() {
  if printf '%s\n' "$output" | grep -qF -- "$2"; then fail "$1: unexpected '$2' in: $output"; fi
}

# Fails with message $1 unless $status is $2.
expect_status() {
  [ "$status" = "$2" ] || fail "$1: expected exit $2, got $status"
}

run "$spec"
expect_status 'nothing covered' 0
expect_line 'lists a scenario with bold removed' \
  'missing 007-US1-S1: Given one pet, When they log, Then it is saved.'
expect_line 'numbers scenarios within their story' \
  'missing 007-US2-S1: Given events, When they look, Then they see them.'
expect_line 'lists an edge case' 'missing 007-EC-01: A time in the future is refused.'
expect_line 'lists a requirement' 'missing 007-FR-002: Logging MUST work offline.'
expect_line 'lists a success criterion' 'missing 007-SC-001: Logging takes under 10 seconds.'
expect_no 'a numbered line outside a story' 'US2-S2'
expect_line 'counts every id' '007-fixture: 0 of 7 ids covered, 7 missing'

run --strict "$spec"
expect_status 'missing ids with --strict' 1

cat >test/domain/a_test.dart <<'DART'
void main() {
  test('007-US1-S1: one pet → saved', () {});
  testWidgets('007-US1-S2, 007-FR-001: picks a pet', (tester) async {});
  // test('007-EC-01: commented out', () {});
  test('a 1007-SC-001 inside a longer id', () {});
}
DART
cat >integration_test/b_test.dart <<'DART'
void main() {
  testWidgets(
    '007-US2-S1: sees events',
    (tester) async {},
  );
}
DART
echo '007-EC-01 in a file that is not Dart' >test/domain/notes.txt
cat >"$spec/untested.md" <<'MD'
# Untested

- 007-SC-001: needs a stopwatch and a person
- 007-FR-002:
MD

run "$spec"
expect_status 'partly covered' 0
expect_no 'covered by a test name' '007-US1-S1:'
expect_no 'several ids in one test name' '007-US1-S2:'
expect_no 'covered by a test name' '007-FR-001:'
expect_no 'covered by an integration test on its own line' '007-US2-S1:'
expect_no 'explained in untested.md' '007-SC-001:'
expect_line 'a commented-out test' 'missing 007-EC-01: A time in the future is refused.'
expect_line 'an untested.md line with no reason' 'missing 007-FR-002: Logging MUST work offline.'
expect_line 'counts covered ids' '007-fixture: 5 of 7 ids covered, 2 missing'

echo '- 007-EC-01: checked by hand' >>"$spec/untested.md"
echo '  test("007-FR-002: offline", () {});' >>integration_test/b_test.dart
run --strict "$spec"
expect_status 'everything covered with --strict' 0
expect_line 'nothing missing' '007-fixture: 7 of 7 ids covered, 0 missing'

run "$spec/" specs/008-other
expect_line 'a trailing slash' '007-fixture: 7 of 7 ids covered, 0 missing'
expect_line "only a spec's own ids count for it" '008-other: 0 of 7 ids covered, 7 missing'

echo "  test('008-FR-001: in a spec that wasn't asked about', () {});" >test/domain/c_test.dart
run --strict "$spec"
expect_status "an id of a spec that wasn't asked about" 0

echo "  test('007-FR-099: not in the spec', () {});" >>test/domain/c_test.dart
echo "  test('008-FR-099: not in the other spec', () {});" >>test/domain/c_test.dart
echo "  test('009-FR-001: no such spec', () {});" >>test/domain/c_test.dart
run "$spec"
expect_status 'an unknown id in a test' 1
expect_line 'names the unknown id and where' 'unknown id 007-FR-099 in test/domain/c_test.dart:2'
expect_line "an unknown id of a spec that wasn't asked about" 'unknown id 008-FR-099 in test/domain/c_test.dart:3'
expect_line 'an id of a spec that does not exist' 'unknown id 009-FR-001 in test/domain/c_test.dart:4'
run "$spec" specs/008-other
[ "$(printf '%s\n' "$output" | grep -c '^unknown id 007-FR-099 ')" = 1 ] ||
  fail "an unknown id is reported once for several specs: $output"
rm test/domain/c_test.dart

echo '- 007-US3-S1: no such story' >>"$spec/untested.md"
run "$spec"
expect_status 'an unknown id in untested.md' 1
expect_line 'names the untested.md line' "unknown id 007-US3-S1 in $spec/untested.md:6"

run
expect_status 'no spec dir' 2
run --loose "$spec"
expect_status 'an unknown option' 2
run specs/no-number
expect_status 'a dir without a spec number' 2
run specs/009-missing
expect_status 'a dir without spec.md' 2

[ "$failures" = 0 ] || exit 1
echo 'spec-coverage.sh tests passed'
