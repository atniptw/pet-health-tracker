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

allows reviewer-bash.sh "git diff --cached -- ':(glob)lib/**' ':(exclude)lib/firebase_options.dart'"
allows reviewer-bash.sh 'git diff HEAD -- firestore.rules'
allows reviewer-bash.sh 'git log --oneline -5'
allows reviewer-bash.sh 'git show HEAD:CLAUDE.md'
allows reviewer-bash.sh 'git grep -n setState -- lib'
allows reviewer-bash.sh 'git status --short'

blocks reviewer-bash.sh 'git commit -m x'
blocks reviewer-bash.sh 'git checkout -- lib'
blocks reviewer-bash.sh 'rm -rf lib'
blocks reviewer-bash.sh 'git diff > out.txt'
blocks reviewer-bash.sh 'git diff --output=out.txt'
blocks reviewer-bash.sh 'git diff --ext-diff'
blocks reviewer-bash.sh 'git grep -O vim foo'
blocks reviewer-bash.sh 'git diff | sh'
blocks reviewer-bash.sh 'git diff; rm -rf lib'
blocks reviewer-bash.sh 'git diff && rm -rf lib'
blocks reviewer-bash.sh 'git diff $(rm -rf lib)'
blocks reviewer-bash.sh 'git -c core.pager=sh diff'
blocks reviewer-bash.sh "git diff
rm -rf lib"

if [ "$failures" -gt 0 ]; then
  echo "$failures hook test(s) failed"
  exit 1
fi
echo 'hook tests passed'
