#!/usr/bin/env bash
# Runs the integration smoke test on the connected Android device. flutter test
# waits forever if the app dies on launch, so the run is capped and the device
# log is printed on failure.
set -uo pipefail
cd "$(dirname "$0")/.."

adb logcat -c
if timeout 600 flutter test integration_test; then
  exit 0
fi

echo '==> crash log'
adb logcat -d -b crash
echo '==> device log'
adb logcat -d | grep -E 'AndroidRuntime|FATAL|flutter|Firebase|libc|DEBUG' | tail -300
exit 1
