#!/usr/bin/env bash
# Tests for scripts/test.sh, with a fake flutter that records how it was run.
set -euo pipefail
cd "$(dirname "$0")/.."
script="$PWD/scripts/test.sh"

failures=0
fail() {
  echo "FAIL test.sh: $1"
  failures=$((failures + 1))
}

dir=$(mktemp -d)
trap 'rm -rf "$dir"' EXIT
fake="$dir/flutter"
cat >"$fake" <<'FAKE'
#!/usr/bin/env bash
printf '%s\n' "$TZ" >"$(dirname "$0")/tz"
printf '%s\n' "$@" >"$(dirname "$0")/args"
exit "${FAKE_EXIT:-0}"
FAKE
chmod +x "$fake"

# Runs test.sh with the fake flutter exiting $1; sets $status and $output. The
# caller's zone is UTC, so only test.sh can set America/Chicago.
run() {
  status=0
  output=$(TZ=UTC FAKE_EXIT=$1 FLUTTER="$fake" "$script" "${@:2}" 2>&1) || status=$?
}

# Fails with message $1 unless flutter got exactly the rest of the arguments.
expect_args() {
  local want
  want=$(printf '%s\n' "${@:2}")
  [ "$(cat "$dir/args")" = "$want" ] || fail "$1, got '$(cat "$dir/args")'"
}

run 0
[ "$status" = 0 ] || fail "passing tests: expected exit 0, got $status"
[ "$output" = 'tests passed' ] || fail "passing tests: expected 'tests passed', got '$output'"
[ "$(cat "$dir/tz")" = America/Chicago ] || fail "sets TZ to America/Chicago, got '$(cat "$dir/tz")'"
expect_args 'runs all tests with the failures-only reporter' test --reporter failures-only

run 1 --coverage test/domain
[ "$status" = 1 ] || fail "failing tests: expected exit 1, got $status"
[ "$output" = 'tests failed' ] || fail "failing tests: expected 'tests failed', got '$output'"
expect_args 'passes its arguments on' test --reporter failures-only --coverage test/domain

run 0 --plain-name 'two words'
expect_args 'keeps an argument with a space whole' test --reporter failures-only --plain-name 'two words'

run 79
[ "$status" = 79 ] || fail "keeps flutter's exit code, expected 79, got $status"

[ "$failures" = 0 ] || exit 1
echo 'test.sh tests passed'
