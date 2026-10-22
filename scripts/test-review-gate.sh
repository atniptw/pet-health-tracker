#!/usr/bin/env bash
# Tests for the review stamp and gate hooks in .claude/hooks, run in a scratch
# git repo with made-up reviewer agents.
set -euo pipefail
cd "$(dirname "$0")/.."
stamp="$PWD/.claude/hooks/review-stamp.sh"
gate="$PWD/.claude/hooks/review-gate.sh"

failures=0
fail() {
  echo "FAIL review hooks: $1"
  failures=$((failures + 1))
}

# check.sh runs from the pre-push hook, where git exports these. Left set, they
# would point the scratch repo's git commands at the real repository.
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_ALTERNATE_OBJECT_DIRECTORIES GIT_COMMON_DIR GIT_PREFIX

repo=$(mktemp -d)
trap 'rm -rf "$repo"' EXIT
cd "$repo"
git init -q
git config user.email test@example.com
git config user.name test
mkdir -p .claude/agents lib docs
printf -- '---\nname: lib-reviewer\n---\n\nPaths: `:(glob)lib/**`\n' >.claude/agents/a.md
printf -- '---\nname: docs-reviewer\n---\n\nPaths: `:(glob)docs/**`\n' >.claude/agents/b.md
git add .claude && git commit -qm agents

# Hook events, as Claude Code sends them.
start() { jq -n --arg id "$1" --arg type "$2" '{hook_event_name: "SubagentStart", agent_id: $id, agent_type: $type}' | "$stamp"; }
handback() {
  jq -n --arg id "$1" --arg type "$2" --arg message "$3" \
    '{hook_event_name: "PostToolUse", tool_name: "SubagentHandback", agent_id: $id, agent_type: $type, tool_input: {message: $message}}' |
    "$stamp"
}
stop() {
  jq -n --arg id "$1" --arg type "$2" --arg last "${3:-}" \
    '{hook_event_name: "SubagentStop", agent_id: $id, agent_type: $type, last_assistant_message: $last}' | "$stamp"
}
# A reviewer run that hands back a report ending in the given verdict.
review() {
  start "$1" "$2"
  handback "$1" "$2" "$(printf 'No findings.\n\nVERDICT: %s' "$3")"
  stop "$1" "$2"
}

other_tool() {
  jq -n --arg id "$1" --arg type "$2" --arg tool "$3" --arg message "$4" \
    '{hook_event_name: "PostToolUse", tool_name: $tool, agent_id: $id, agent_type: $type, tool_input: {message: $message}}' |
    "$stamp"
}

expect_gate() {
  local want=$1 label=$2 command=${3:-git commit -q -m x} got=0 input
  input=$(jq -n --arg c "$command" '{hook_event_name: "PreToolUse", tool_name: "Bash", tool_input: {command: $c}}')
  printf '%s' "$input" | PATH="${GATE_PATH:-$PATH}" "${GATE:-$gate}" >/dev/null 2>&1 || got=$?
  [ "$got" = "$want" ] || fail "$label: expected exit $want, got $got"
}
allows() { expect_gate 0 "$@"; }
blocks() { expect_gate 2 "$@"; }

echo x >README.md && git add README.md
allows 'a change no reviewer covers'
git commit -qm readme

allows 'a command that is not a commit' 'git status'
allows 'echo' 'echo git commit'

echo x >lib/a.dart && git add lib/a.dart
blocks 'a lib change with no review'
message=$(jq -n '{hook_event_name: "PreToolUse", tool_name: "Bash", tool_input: {command: "git commit -m x"}}' | "$gate" 2>&1 >/dev/null || true)
case "$message" in *lib-reviewer*) ;; *) fail "the message names the missing reviewer: got '$message'" ;; esac

review r1 lib-reviewer PASS
allows 'a lib change its reviewer passed'
allows 'a commit with its message in a heredoc' 'git commit -q -m "$(cat <<'"'EOF'"'
feat: a
EOF
)"'
blocks 'commit -a, which commits unreviewed changes' 'git commit -a -m x'
blocks 'commit --all' 'git commit --all -m x'
blocks 'commit -am' 'git commit -am x'

echo y >>lib/a.dart && git add lib/a.dart
blocks 'a change staged after the review'
review r2 lib-reviewer PASS
allows 'the change reviewed again'

echo x >docs/a.md && git add docs/a.md
blocks 'a second reviewer still missing'
message=$(jq -n '{hook_event_name: "PreToolUse", tool_name: "Bash", tool_input: {command: "git commit -m x"}}' | "$gate" 2>&1 >/dev/null || true)
case "$message" in *docs-reviewer*lib-reviewer* | *lib-reviewer*docs-reviewer*) fail "names only the missing reviewer: got '$message'" ;; *docs-reviewer*) ;; *) fail "names docs-reviewer: got '$message'" ;; esac
review r3 docs-reviewer PASS
allows 'both reviewers passed'

echo z >>docs/a.md && git add docs/a.md
review r4 docs-reviewer FAIL
blocks 'a failed review'
echo z >>docs/a.md && git add docs/a.md
start r5 docs-reviewer
echo w >>docs/a.md && git add docs/a.md
handback r5 docs-reviewer 'VERDICT: PASS'
stop r5 docs-reviewer
blocks 'a change staged while the reviewer ran'

start r6 docs-reviewer
stop r6 docs-reviewer 'No findings.
VERDICT: PASS'
allows 'a verdict in the last message, with no handback'

echo v >>docs/a.md && git add docs/a.md
start r7 docs-reviewer
handback r7 docs-reviewer 'VERDICT: PASS
On a second look, one finding.
VERDICT: FAIL'
stop r7 docs-reviewer
blocks 'only the last line counts'

start r8 docs-reviewer
stop r8 docs-reviewer
blocks 'no report at all'

review r9 docs-reviewer PASS
allows 'passed after the failures'
review r9 docs-reviewer FAIL
blocks 'a later FAIL of the same diff removes the pass'

review r10 docs-reviewer PASS
start r10 docs-reviewer
stop r10 docs-reviewer
blocks 'a continued reviewer must hand back a new report'

review r11 Explore PASS
review r12 docs-reviewer PASS
[ -z "$(ls "$(git rev-parse --git-path review-stamps)/stamps" | grep -v -e lib-reviewer -e docs-reviewer)" ] ||
  fail 'an agent that is not a reviewer leaves no stamp'
allows 'other agents do not change the result'

# Agent ids and reports.
echo u >>docs/a.md && git add docs/a.md
start '../stamps/docs-reviewer' docs-reviewer
blocks 'an agent id cannot name a path'
start '' docs-reviewer
stop '' docs-reviewer 'VERDICT: PASS'
blocks 'an event without an agent id is ignored'
start r13 docs-reviewer
handback r13 docs-reviewer 'VERDICT: FAIL'
stop r13 docs-reviewer 'VERDICT: PASS'
blocks 'the handback, not the last message, is the report'
start r14 docs-reviewer
handback r14 docs-reviewer 'VERDICT: PASS'
start r14 docs-reviewer
stop r14 docs-reviewer
blocks 'a restarted run drops the earlier report'
start r15 docs-reviewer
other_tool r15 docs-reviewer SendMessage 'VERDICT: PASS'
stop r15 docs-reviewer 'VERDICT: FAIL'
blocks 'only a handback is a report'
start r16 docs-reviewer
handback r16 docs-reviewer $'No findings.\n\n  VERDICT: PASS  \n\n'
stop r16 docs-reviewer
allows 'a verdict line with spaces and blank lines around it'
allows 'a flag mentioned in a double-quoted message' 'git commit -q -m "stop using -a"'
allows 'a flag mentioned in a single-quoted message' "git commit -q -m 'not --all'"

# Commit forms the gate recognises.
echo u >>lib/a.dart && git add lib/a.dart
blocks 'git -C' 'git -C . commit -m x'
blocks 'git -c' 'git -c a.b=c commit -m x'
blocks 'a commit after &&' 'true && git commit -m x'
blocks 'a commit in a subshell' '(git commit -m x)'
blocks 'a commit inside bash -c' "bash -c 'git commit -m x'"
blocks 'a commit inside sh -c' 'sh -c "git commit -m x"'
blocks 'a commit after a variable' 'GIT_EDITOR=true git commit -m x'
blocks 'a commit through env' 'env git commit -m x'
blocks 'a commit by full path' '/usr/bin/git commit -m x'
blocks 'a commit inside if' 'if true; then git commit -m x; fi'
blocks 'a quoted git option value with a space' 'git -c user.name="A B" commit -m x'
allows 'git grep for the word commit' 'git grep -n "commit" -- lib'
allows 'git log searching for commit' 'git log --oneline --grep commit'
allows 'git log with commit in its format' 'git log --format="%h commit %s"'
review r17 lib-reviewer PASS
allows 'all reviewed again'

# Only these options are allowed, since the gate checks only the staged change.
allows 'the allowed options' 'git commit -q -s -v --no-edit --allow-empty --dry-run -m x'
allows 'a bundle of allowed flags' 'git commit -qm x'
allows '--message=' "git commit --message='x'"
allows '--amend' 'git commit --amend --no-edit'
allows '--message with a separate value' 'git commit --message "x"'
allows 'an unquoted --message=' 'git commit --message=x'
allows 'the long flags' 'git commit --quiet --signoff --verbose -m x'
allows 'a redirect after the commit' 'git commit -q -m x 2>&1 | tail -5'
allows 'output sent to /dev/null' 'git commit -q -m x >/dev/null'
allows 'a redirect with its target apart' 'git commit -q -m x > out.txt'
blocks 'a pathspec after a redirect' 'git commit -q -m x >/dev/null lib/a.dart'
blocks 'an option after a redirect' 'git commit -q -m x 2> err -o lib/a.dart'
blocks 'a pathspec after 2>&1' 'git commit -q -m x 2>&1 lib/a.dart'
allows '&> after the commit' 'git commit -q -m x &>/dev/null'
allows '&>> with its target apart' 'git commit -q -m x &>> log'
blocks 'a pathspec after &>' 'git commit -q -m x &> log lib/a.dart'
allows 'a git option value with a space' 'git -c user.name="A B" commit -q -m x'
allows 'staging and committing in one command' 'git add lib/a.dart && git commit -q -m x'
allows 'cd into this repo first' "cd $repo && git commit -q -m x"
blocks 'a pathspec' 'git commit -m x lib/a.dart'
blocks 'a pathspec after --' 'git commit -m x -- lib/a.dart'
blocks '-o' 'git commit -o -m x lib/a.dart'
blocks '--only' 'git commit --only -m x lib/a.dart'
blocks '-i' 'git commit -i -m x lib/a.dart'
blocks '--include' 'git commit --include -m x lib/a.dart'
blocks '--pathspec-from-file' 'git commit --pathspec-from-file=paths -m x'
blocks '-F' 'git commit -F message.txt'

# A commit into another repository or worktree is denied.
other=$(mktemp -d)
git init -q "$other"
blocks 'git -C another repository' "git -C $other commit -m x"
blocks 'cd into another repository' "cd $other && git commit -m x"
blocks 'git -C a directory that does not exist' 'git -C /no/such/dir commit -m x'
blocks 'git -C a quoted path with a space' 'git -C "/no such/dir" commit -m x'
rm -rf "$other"

# If jq can't read the command, a commit is denied and anything else allowed.
nojq=$(mktemp -d)
printf '#!/bin/sh\nexit 1\n' >"$nojq/jq" && chmod +x "$nojq/jq"
GATE_PATH="$nojq:$PATH" blocks 'jq fails on a commit'
GATE_PATH="$nojq:$PATH" allows 'jq fails on another command' 'git status'
rm -rf "$nojq"

# A gate with a missing helper or a misbehaving reviewer mapping denies the
# commit.
stub=$(mktemp -d)
mkdir -p "$stub/.claude/hooks" "$stub/scripts"
cp "$gate" "$stub/.claude/hooks/"
GATE="$stub/.claude/hooks/review-gate.sh" blocks 'its command-text.sh is missing'
cp "$(dirname "$gate")/command-text.sh" "$stub/.claude/hooks/"
printf '#!/usr/bin/env bash\n[ "${1:-}" = --hashes ] && exit 1\necho lib-reviewer\n' >"$stub/scripts/required-reviewers.sh"
chmod +x "$stub/scripts/required-reviewers.sh"
GATE="$stub/.claude/hooks/review-gate.sh" blocks 'the hashes fail'
printf '#!/usr/bin/env bash\n[ "${1:-}" = --hashes ] && exit 0\necho ghost-reviewer\n' >"$stub/scripts/required-reviewers.sh"
GATE="$stub/.claude/hooks/review-gate.sh" blocks 'a required reviewer has no hash'
rm -rf "$stub"
# A command inside the gate that fails, here awk, must not let the commit through.
broken=$(mktemp -d)
printf '#!/bin/sh\nexit 1\n' >"$broken/awk" && chmod +x "$broken/awk"
PATH="$broken:$PATH" blocks 'an unexpected error in the gate'
rm -rf "$broken"

printf -- '---\nname: broken\n---\n\nNo paths.\n' >.claude/agents/c.md && git add .claude/agents/c.md
blocks 'the reviewer mapping fails'

if [ "$failures" -gt 0 ]; then
  echo "$failures review hook test(s) failed"
  exit 1
fi
echo 'review hook tests passed'
