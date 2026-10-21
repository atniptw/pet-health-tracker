#!/usr/bin/env bash
# Fails if line coverage in coverage/lcov.info is below the minimum, more than
# SLACK above it (so the minimum gets raised), or if any file in lib/ is missing
# from it (flutter test only reports files a test loads, so an untested new file
# would otherwise not count against the total).
set -euo pipefail
cd "${COVERAGE_ROOT:-$(dirname "$0")/..}"

# Raise this as coverage goes up; never lower it.
MIN=99.2
SLACK=0.2

# main.dart only boots Firebase and runApp; firebase_options.dart is generated.
EXCLUDE='^lib/(main|firebase_options)\.dart$'

missing=$(comm -23 \
  <(find lib -name '*.dart' | grep -Ev "$EXCLUDE" | sort) \
  <(sed -n 's/^SF://p' coverage/lcov.info | sort))
if [ -n "$missing" ]; then
  echo "No test loads these files, so their coverage is unknown:"
  echo "$missing"
  exit 1
fi

awk -F: -v min="$MIN" -v slack="$SLACK" -v exclude="$EXCLUDE" '
  /^SF:/ { skip = ($2 ~ exclude) }
  /^LF:/ && !skip { found += $2 }
  /^LH:/ && !skip { hit += $2 }
  END {
    pct = 100 * hit / found
    printf "line coverage %.2f%% (minimum %g%%)\n", pct, min
    if (pct < min - 1e-9) exit 1
    if (pct > min + slack + 1e-9) {
      printf "Coverage is more than %g%% above the minimum: raise MIN in scripts/coverage.sh to %.1f\n", slack, int(pct * 10) / 10
      exit 1
    }
  }
' coverage/lcov.info
