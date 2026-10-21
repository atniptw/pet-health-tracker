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
blocks block-no-verify.sh 'git config core.hooksPath ./hooks'
blocks block-no-verify.sh 'git config --unset-all core.hooksPath'
blocks block-no-verify.sh 'git commit "--no-verify" -m x'
blocks block-no-verify.sh "git commit '-n' -m x"
blocks block-no-verify.sh 'git push "--no-verify"'
blocks block-no-verify.sh 'git commit --no-veri -m x'
blocks block-no-verify.sh 'git push --no-verif'
blocks block-no-verify.sh 'bash -c "git commit --no-verify"'
blocks block-no-verify.sh 'bash -c "git commit -n"'
blocks block-no-verify.sh "git config alias.ci '!git commit --no-verify'"
blocks block-no-verify.sh 'git config alias.ci commit\ --no-verify'
blocks block-no-verify.sh 'git config alias.ci commit\ -n'
blocks block-no-verify.sh 'git -c "core.hooksPath=/dev/null" commit'
blocks block-no-verify.sh 'git config core.hooksPath "/tmp/none"'
blocks block-no-verify.sh 'git -c core.hookspath=/dev/null commit'
blocks block-no-verify.sh 'git config CORE.HOOKSPATH /tmp/none'
blocks block-no-verify.sh 'git -c core.hooksPath=.git/hooks push'
blocks block-no-verify.sh 'git config core.hooksPath .gitx'
blocks block-no-verify.sh 'git config core.hooksPath ./.githooks'
blocks block-no-verify.sh 'GIT_CONFIG_KEY_0=core.hooksPath GIT_CONFIG_VALUE_0=/tmp git push'
blocks block-no-verify.sh 'COVERAGE_ROOT=/tmp/fake git push'
blocks block-no-verify.sh 'export COVERAGE_ROOT=/tmp/fake'
blocks block-no-verify.sh 'git config alias.c commit'
blocks block-no-verify.sh 'git config alias.p push'
blocks block-no-verify.sh 'git -C repo commit -n -m x'
blocks block-no-verify.sh 'git config core.hooksPath .githooks-off'
blocks block-no-verify.sh 'bash -c -m "git push --no-verify"'
blocks block-no-verify.sh "bash -cm 'git push --no-verify'"
blocks block-no-verify.sh 'git push --no-ver{i,i}fy'
blocks block-no-verify.sh "git push \$'\\x2d-no-verify'"
blocks block-no-verify.sh 'X=--no-ver; git push ${X}ify'
blocks block-no-verify.sh 'R=ROOT; export COVERAGE_$R=/tmp/fake; ./scripts/check.sh'
blocks block-no-verify.sh 'export GIT_CONFIG_COUNT=1 GIT_CONFIG_VALUE_0=/dev/null GIT_CONFIG_KEY_0=core.hooksPath; git push'
blocks block-no-verify.sh 'GIT_CONFIG_VALUE_0=/dev/null GIT_CONFIG_KEY_0=core.hooksPath && git push'
blocks block-no-verify.sh 'git send-pack origin HEAD:refs/heads/main'
blocks block-no-verify.sh 'git config set core.hooksPath /tmp/none'
blocks block-no-verify.sh 'git config unset core.hooksPath'
blocks block-no-verify.sh 'git config --global core.hooksPath /tmp/none'
blocks block-no-verify.sh "GIT_CONFIG_PARAMETERS=\"'core.hooksPath=/tmp/none'\" git push"

allows block-no-verify.sh 'git commit -m "fix: block --no-verify"'
allows block-no-verify.sh "git commit -m 'skip -n here'"
allows block-no-verify.sh 'git commit -am "x"'
allows block-no-verify.sh 'git push -u origin main'
allows block-no-verify.sh 'git push -n'
allows block-no-verify.sh 'git config core.hooksPath .githooks'
allows block-no-verify.sh 'git config core.hooksPath'
allows block-no-verify.sh 'git log --oneline -n 5'
allows block-no-verify.sh 'echo done'
allows block-no-verify.sh "git commit --message='skip --no-verify'"
allows block-no-verify.sh 'git commit --verbose -m x'
allows block-no-verify.sh 'git commit -q -m "$(cat <<'"'EOF'"'
docs: explain why --no-verify and -n are blocked
EOF
)"'
allows block-no-verify.sh 'git config core.hooksPath ".githooks"'
allows block-no-verify.sh 'git config alias.st status'
allows block-no-verify.sh 'git commit -am "skip -n here"'
allows block-no-verify.sh 'git commit -m "say \"hi\" --no-verify"'
allows block-no-verify.sh 'git commit -m x && git log -n 5'
allows block-no-verify.sh 'git grep -n COVERAGE_ROOT -- scripts'
allows block-no-verify.sh 'git commit -q -m "$(cat <<'"'EOF'"'
fix(hooks): catch quoted flags like "--no-verify" and "core.hooksPath"
EOF
)"'
allows block-no-verify.sh 'git config --get core.hooksPath'
allows block-no-verify.sh 'git config --get-all core.hooksPath'
allows block-no-verify.sh 'git config --show-origin core.hooksPath'
allows block-no-verify.sh 'git grep -n core.hooksPath -- docs'
allows block-no-verify.sh 'grep core.hooksPath docs/ci.md'
allows block-no-verify.sh 'grep -rn -- --no-verify docs'
allows block-no-verify.sh 'git grep -n -e --no-verify'
allows block-no-verify.sh 'git log -n 5 @{u}'
allows block-no-verify.sh 'git diff $(git merge-base HEAD main)'
allows block-no-verify.sh 'echo $HOME'
allows block-no-verify.sh 'git config --get core.hooksPath --default .githooks'
allows block-no-verify.sh 'git config core.hooksPath 2>/dev/null || echo unset'
allows block-no-verify.sh 'git config --get core.hooksPath >/dev/null && echo set'
allows block-no-verify.sh 'grep -c core.hooksPath docs/ci.md'
allows block-no-verify.sh 'grep -rn "config core.hooksPath" .'
allows block-no-verify.sh 'git config core.hooksPath .githooks>/dev/null'
allows block-no-verify.sh 'git status && grep -c core.hooksPath docs/ci.md'
allows block-no-verify.sh 'git commit -m one -m "two --no-verify"'

allows reviewer-bash.sh "git diff --cached -- ':(glob)lib/**' ':(exclude)lib/firebase_options.dart'"
allows reviewer-bash.sh 'git diff HEAD -- firestore.rules'
allows reviewer-bash.sh 'git log --oneline -5'
allows reviewer-bash.sh 'git show HEAD:CLAUDE.md'
allows reviewer-bash.sh 'git grep -n setState -- lib'
allows reviewer-bash.sh 'git status --short'
allows reviewer-bash.sh 'git blame lib/main.dart'
allows reviewer-bash.sh 'git ls-files lib'

blocks reviewer-bash.sh 'git commit -m x'
blocks reviewer-bash.sh 'git checkout -- lib'
blocks reviewer-bash.sh 'rm -rf lib'
blocks reviewer-bash.sh 'git diff > out.txt'
blocks reviewer-bash.sh 'git diff --output=out.txt'
blocks reviewer-bash.sh 'git diff --ext-diff'
blocks reviewer-bash.sh 'git grep -O vim foo'
blocks reviewer-bash.sh 'git grep --open-files-in-pager=vim foo'
blocks reviewer-bash.sh 'git log --exec=sh'
blocks reviewer-bash.sh 'git diff `rm -rf lib`'
blocks reviewer-bash.sh 'git diff < /etc/passwd'
blocks reviewer-bash.sh 'git diff | sh'
blocks reviewer-bash.sh 'git diff; rm -rf lib'
blocks reviewer-bash.sh 'git diff && rm -rf lib'
blocks reviewer-bash.sh 'git diff $(rm -rf lib)'
blocks reviewer-bash.sh 'git -c core.pager=sh diff'
blocks reviewer-bash.sh 'git diff "--output=/tmp/x"'
blocks reviewer-bash.sh "git diff --out''put=lib/a.dart"
blocks reviewer-bash.sh "git grep '-Osh' -e x"
blocks reviewer-bash.sh 'git grep -lOsh -e . -- scripts/check.sh'
blocks reviewer-bash.sh 'git grep --open=sh -e . -- scripts/check.sh'
blocks reviewer-bash.sh 'git diff --ext'
blocks reviewer-bash.sh 'git diff --out\put=lib/a.dart'
blocks reviewer-bash.sh 'git diff ${X:---output=lib/a.dart}'
blocks reviewer-bash.sh 'git diff {--output=lib/a.dart,}'
blocks reviewer-bash.sh "git diff \$'\\055\\055output=lib/a.dart'"
blocks reviewer-bash.sh 'git grep ${X:--Osh} -e . -- scripts/check.sh'
blocks reviewer-bash.sh 'git log --exe=sh'
blocks reviewer-bash.sh "git diff
rm -rf lib"

if [ "$failures" -gt 0 ]; then
  echo "$failures hook test(s) failed"
  exit 1
fi
echo 'hook tests passed'
