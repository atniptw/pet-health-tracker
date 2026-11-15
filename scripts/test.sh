#!/usr/bin/env bash
# Runs the Flutter tests in test/ the same way everywhere: in one time zone, so
# dates behave alike on a laptop and in CI, and printing only failing tests and
# a one-line result. Arguments go to `flutter test` (files, --coverage, ...).
set -uo pipefail
cd "$(dirname "$0")/.."

status=0
TZ=America/Chicago "${FLUTTER:-flutter}" test --reporter failures-only "$@" || status=$?
if [ "$status" = 0 ]; then
  echo 'tests passed'
else
  echo 'tests failed'
fi
exit "$status"
