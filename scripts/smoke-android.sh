#!/usr/bin/env bash
# Runs the integration smoke test on the connected Android device.
#
# flutter test can hang with no output (seen in CI after the app launched), so
# each attempt is capped. An attempt that times out is retried once: a real
# startup hang times out twice and still fails. A test that fails is not
# retried. On failure the verbose tool log and the device log are printed, to
# show where it stopped.
set -uo pipefail
cd "$(dirname "$0")/.."

# A passing attempt takes about 2.5 minutes, most of it the Gradle build.
ATTEMPT_SECONDS=${SMOKE_ATTEMPT_SECONDS:-420}
log=$(mktemp)

print_failure() {
  echo '==> flutter test log (verbose, last 300 lines)'
  tail -n 300 "$log"
  echo '==> crash log'
  adb logcat -d -b crash
  echo '==> device log'
  adb logcat -d | grep -E 'AndroidRuntime|FATAL|flutter|Firebase|libc|DEBUG' | tail -300
}

for attempt in 1 2; do
  adb logcat -c
  # Interrupt first so the tool can flush its output, then kill if it won't stop.
  timeout -s INT -k 30 "$ATTEMPT_SECONDS" flutter test -v integration_test >"$log" 2>&1
  status=$?
  if [ "$status" -eq 0 ]; then
    # The output without the verbose trace lines, which start with "[".
    grep -v '^\[' "$log"
    exit 0
  fi
  # 124: timed out after the interrupt; 137: killed after the grace period.
  if [ "$attempt" -eq 1 ] && { [ "$status" -eq 124 ] || [ "$status" -eq 137 ]; }; then
    print_failure
    echo "==> timed out after ${ATTEMPT_SECONDS}s; retrying once"
    continue
  fi
  break
done

print_failure
exit 1
