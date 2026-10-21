#!/usr/bin/env bash
# Tests for scripts/coverage.sh, run against generated lcov files.
set -euo pipefail
cd "$(dirname "$0")/.."

min=$(sed -n 's/^MIN=//p' scripts/coverage.sh)
slack=$(sed -n 's/^SLACK=//p' scripts/coverage.sh)
root=$(mktemp -d)
trap 'rm -rf "$root"' EXIT
mkdir -p "$root/lib" "$root/coverage"
touch "$root/lib/a.dart" "$root/lib/main.dart"

failures=0

# Writes an lcov file where lib/a.dart has the given line coverage (in %).
# lib/main.dart is excluded, so its 0% must not count.
lcov() {
  local hit
  hit=$(awk -v p="$1" 'BEGIN { printf "%d", p * 1000 + 0.5 }')
  printf 'SF:lib/a.dart\nLF:100000\nLH:%s\nend_of_record\n' "$hit" >"$root/coverage/lcov.info"
  printf 'SF:lib/main.dart\nLF:100\nLH:0\nend_of_record\n' >>"$root/coverage/lcov.info"
}

expect() {
  local want=$1 label=$2 got=0
  COVERAGE_ROOT=$root scripts/coverage.sh >/dev/null || got=$?
  if [ "$got" != "$want" ]; then
    echo "FAIL coverage.sh: expected exit $want, got $got: $label"
    failures=$((failures + 1))
  fi
}

at() { awk -v m="$min" -v d="$1" 'BEGIN { print m + d }'; }
at_slack() { awk -v s="$slack" -v d="$1" 'BEGIN { print s + d }'; }

lcov "$min"; expect 0 'at the minimum'
lcov "$(at "$slack")"; expect 0 'at the minimum plus slack'
lcov "$(at -0.01)"; expect 1 'below the minimum'
lcov "$(at "$(at_slack 0.01)")"; expect 1 'more than slack above the minimum'

lcov "$min"; touch "$root/lib/b.dart"; expect 1 'a lib file no test loads'

if [ "$failures" -gt 0 ]; then
  echo "$failures coverage test(s) failed"
  exit 1
fi
echo 'coverage tests passed'
