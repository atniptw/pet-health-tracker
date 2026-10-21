#!/usr/bin/env bash
# Tests for the Claude Code hooks in .claude/hooks.
set -euo pipefail
cd "$(dirname "$0")/.."

failures=0

expect() {
  local want=$1 hook=$2 command=$3 got=0
  jq -n --arg c "$command" '{tool_input: {command: $c}}' \
    | ".claude/hooks/$hook" 2>/dev/null || got=$?
  if [ "$got" != "$want" ]; then
    echo "FAIL $hook: expected exit $want, got $got for: $command"
    failures=$((failures + 1))
  fi
}

blocks() { expect 2 "$@"; }
allows() { expect 0 "$@"; }

blocks block-no-verify.sh 'git commit --no-verify -m "x"'
blocks block-no-verify.sh 'git push --no-verify'
blocks block-no-verify.sh 'git push -u origin main --no-verify'
blocks block-no-verify.sh 'cd repo && git commit -m "x" --no-verify'
blocks block-no-verify.sh 'git -C repo commit --no-verify'
blocks block-no-verify.sh 'git commit -n -m "x"'
blocks block-no-verify.sh 'git commit -anm "x"'
blocks block-no-verify.sh 'git -c core.hooksPath=/dev/null push'
blocks block-no-verify.sh 'git config core.hooksPath /tmp/none'
blocks block-no-verify.sh 'git config core.hooksPath ""'
blocks block-no-verify.sh 'git config --unset core.hooksPath'

allows block-no-verify.sh 'git commit -m "fix: block --no-verify"'
allows block-no-verify.sh "git commit -m 'skip -n here'"
allows block-no-verify.sh 'git commit -am "x"'
allows block-no-verify.sh 'git push -u origin main'
allows block-no-verify.sh 'git push -n'
allows block-no-verify.sh 'git config core.hooksPath .githooks'
allows block-no-verify.sh 'git config core.hooksPath'
allows block-no-verify.sh 'git log --oneline -n 5'
allows block-no-verify.sh 'echo done'

if [ "$failures" -gt 0 ]; then
  echo "$failures hook test(s) failed"
  exit 1
fi
echo 'hook tests passed'
