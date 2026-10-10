#!/usr/bin/env bash
# Fails if line coverage in coverage/lcov.info is below the minimum, or if any
# file in lib/ is missing from it (flutter test only reports files a test loads,
# so an untested new file would otherwise not count against the total).
set -euo pipefail
cd "$(dirname "$0")/.."

# Raise this as coverage goes up; never lower it.
MIN=99

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

awk -F: -v min="$MIN" -v exclude="$EXCLUDE" '
  /^SF:/ { skip = ($2 ~ exclude) }
  /^LF:/ && !skip { found += $2 }
  /^LH:/ && !skip { hit += $2 }
  END {
    pct = 100 * hit / found
    printf "line coverage %.1f%% (minimum %d%%)\n", pct, min
    if (pct < min) exit 1
  }
' coverage/lcov.info
