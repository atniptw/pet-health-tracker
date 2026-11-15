#!/usr/bin/env bash
# Tests for scripts/autopilot.sh, run in a scratch clone of a scratch origin,
# with a fake claude that records each session and ticks one task from a clone
# of its own, and a fake sleep that records how long it was asked to wait.
set -euo pipefail
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_ALTERNATE_OBJECT_DIRECTORIES GIT_COMMON_DIR GIT_PREFIX
cd "$(dirname "$0")/.."
script="$PWD/scripts/autopilot.sh"

failures=0
fail() {
  echo "FAIL autopilot.sh: $1"
  failures=$((failures + 1))
}

dir=$(mktemp -d)
trap 'rm -rf "$dir"' EXIT
mkdir "$dir/bin"
fake="$dir/bin/claude"
cat >"$fake" <<'FAKE'
#!/usr/bin/env bash
printf '%s|%s|%s\n' "$SPECIFY_FEATURE_DIRECTORY" "$SPECIFY_FEATURE_NO_PERSIST" "$*" >>"$FAKE_LOG"
calls=$(wc -l <"$FAKE_LOG" | tr -d ' ')
echo 'session output'
# FAKE_LIMIT=<n> stops each of the first n sessions on a usage limit, with
# FAKE_RESET as the reset time when it is set.
if [ "$calls" -le "${FAKE_LIMIT:-0}" ]; then
  # FAKE_GATE=<path> also writes that file before stopping, and
  # FAKE_GATE_COMMIT=1 commits it on a branch of its own.
  if [ -n "${FAKE_GATE:-}" ]; then
    mkdir -p "$(dirname "$FAKE_GATE")"
    echo edited >"$FAKE_GATE"
  fi
  if [ "${FAKE_GATE_COMMIT:-}" = 1 ]; then
    git switch -q -c gate-edit
    git add "$FAKE_GATE"
    git -c user.name=t -c user.email=t@t commit -q -m gate
  fi
  printf '{"type":"result","is_error":true,"result":"Claude AI usage limit reached%s"}\n' "${FAKE_RESET:+|$FAKE_RESET}"
  exit 1
fi
# FAKE_IDLE=1 does nothing in the first session only, so a driver that ignores
# it still ends instead of looping.
if [ "${FAKE_IDLE:-}" = 1 ] && [ "$calls" -eq 1 ]; then
  exit 3
fi
# FAKE_ERROR=1 ends the first session on an error that isn't a usage limit.
if [ "${FAKE_ERROR:-}" = 1 ] && [ "$calls" -eq 1 ]; then
  echo '{"type":"result","is_error":true,"result":"API Error: 500"}'
  exit 1
fi
clone=$(mktemp -d)
git clone -q "$FAKE_ORIGIN" "$clone" 2>/dev/null
tasks="$clone/$SPECIFY_FEATURE_DIRECTORY/tasks.md"
if [ -e "$tasks" ]; then
  awk '!done && /^- \[ \] / { sub(/^- \[ \] /, "- [X] "); done = 1 } { print }' "$tasks" >"$tasks.new"
  mv "$tasks.new" "$tasks"
else
  printf '## Phase 1: Only\n\n- [ ] T001 Something\n' >"$tasks"
fi
git -C "$clone" add -A
git -C "$clone" -c user.name=t -c user.email=t@t commit -q -m step
git -C "$clone" push -q origin HEAD:main
rm -rf "$clone"
# FAKE_LITTER=1 leaves a file behind in the checkout it was started in.
[ "${FAKE_LITTER:-}" != 1 ] || echo litter >litter
FAKE
chmod +x "$fake"
cat >"$dir/bin/sleep" <<'FAKE'
#!/usr/bin/env bash
echo "$1" >>"$FAKE_SLEEPS"
FAKE
chmod +x "$dir/bin/sleep"

tasks_2_3='## Phase 1: Setup

- [X] T001 Done

## Phase 2: Foundational

- [ ] T002 First

## Phase 3: User Story 1

- [ ] T003 Second
'

# Makes a scratch origin and a clone of it in $work holding autopilot.sh and
# the specs given as pairs of spec dir and tasks.md text ("" for no tasks.md).
setup() {
  rm -rf "$dir/origin.git" "$dir/work" "$dir/sessions" "$dir/sleeps"
  git init -q --bare -b main "$dir/origin.git"
  git clone -q "$dir/origin.git" "$dir/work" 2>/dev/null
  work="$dir/work"
  mkdir -p "$work/scripts"
  cp "$script" "$work/scripts/"
  while [ $# -gt 0 ]; do
    mkdir -p "$work/$1"
    echo '# Spec' >"$work/$1/spec.md"
    [ -z "$2" ] || printf '%s' "$2" >"$work/$1/tasks.md"
    shift 2
  done
  commit_and_push "$work"
}

commit_and_push() {
  git -C "$1" add -A
  git -C "$1" -c user.name=t -c user.email=t@t commit -q -m fixture
  git -C "$1" push -q origin HEAD:main
}

# Pushes $2 as the content of file $1 to origin from a second clone, so only a
# fetch shows it to $work.
push_from_elsewhere() {
  rm -rf "$dir/other"
  git clone -q "$dir/origin.git" "$dir/other" 2>/dev/null
  printf '%s' "$2" >"$dir/other/$1"
  commit_and_push "$dir/other"
}

# Runs autopilot.sh in $work with the given arguments; sets $status, $output,
# $sessions (one line per fake claude session, its session id shown as ID) and
# $sleeps (one line per wait).
run() {
  status=0
  output=$(cd "$work" && PATH="$dir/bin:$PATH" FAKE_ORIGIN="$dir/origin.git" FAKE_LOG="$dir/sessions" \
    FAKE_SLEEPS="$dir/sleeps" CLAUDE="$fake" ./scripts/autopilot.sh "$@" 2>&1) || status=$?
  sessions=$(sed -E 's/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/ID/g' "$dir/sessions" 2>/dev/null || true)
  sleeps=$(cat "$dir/sleeps" 2>/dev/null || true)
}

flags='--permission-mode auto --permission-prompts none --output-format json'
step_prompt() {
  echo "$1|1|-p Autonomous run. $2, as docs/dev-workflow/autonomous-runs.md says. --session-id ID $flags"
}
resume_line="specs/001-a|1|-p Autonomous run. A usage limit stopped this step; carry on from where it stopped. --resume ID $flags"

setup specs/001-a ''
run --next
[ "$output" = 'plan specs/001-a' ] || fail "no tasks.md: expected 'plan specs/001-a', got '$output'"

setup specs/001-a "$tasks_2_3"
run --next
[ "$output" = 'phase 2 specs/001-a' ] || fail "first unticked task in phase 2: got '$output'"

setup specs/001-a '## Phase 1: Setup

- [X] T001 Done

## Phase 2

- [ ] T002 First
'
run --next
[ "$output" = 'phase 2 specs/001-a' ] || fail "phase heading without a colon: got '$output'"

setup specs/001-a '- [X] T001 Done
' specs/002-b ''
run --next
[ "$output" = 'plan specs/002-b' ] || fail "first spec built: expected 'plan specs/002-b', got '$output'"

setup specs/001-a '## Phase 1: Setup

- [X] T001 Done
'
run --next
[ -z "$output" ] || fail "every task ticked: expected no step, got '$output'"

setup specs/001-a "$tasks_2_3" specs/002-b ''
run
[ "$status" = 0 ] || fail "run to the end: expected exit 0, got $status: $output"
[[ "$output" == *'autopilot: every spec is built'* ]] || fail "run to the end: expected the done line, got '$output'"
want="$(step_prompt specs/001-a 'Phase 2 of specs/001-a')
$(step_prompt specs/001-a 'Phase 3 of specs/001-a')
$(step_prompt specs/002-b 'Plan specs/002-b')
$(step_prompt specs/002-b 'Phase 1 of specs/002-b')"
[ "$sessions" = "$want" ] || fail "run to the end: one session per step from main, got '$sessions'"
[ -z "$sleeps" ] || fail "run to the end: expected no waits, got '$sleeps'"
uuid='[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}'
[ "$(grep -oE "$uuid" "$dir/sessions" | sort -u | wc -l | tr -d ' ')" = 4 ] ||
  fail 'run to the end: expected a session id of its own for each step'

setup specs/001-a "$tasks_2_3"
push_from_elsewhere specs/001-a/tasks.md "${tasks_2_3/- \[ \] T002/- [X] T002}"
run
[ "$(head -n 1 <<<"$sessions")" = "$(step_prompt specs/001-a 'Phase 3 of specs/001-a')" ] ||
  fail "main moved ahead: expected the first step from origin's main, got '$sessions'"

setup specs/001-a "$tasks_2_3"
status=0
output=$(cd "$work" && FAKE_IDLE=1 PATH="$dir/bin:$PATH" FAKE_ORIGIN="$dir/origin.git" FAKE_LOG="$dir/sessions" \
  FAKE_SLEEPS="$dir/sleeps" CLAUDE="$fake" ./scripts/autopilot.sh 2>&1) || status=$?
[ "$status" = 1 ] || fail "step leaves main unchanged: expected exit 1, got $status"
[[ "$output" == *'phase 2 specs/001-a left main unchanged (session exit 3); see '* ]] || fail "step leaves main unchanged: got '$output'"
[ "$(wc -l <"$dir/sessions" | tr -d ' ')" = 1 ] || fail 'step leaves main unchanged: expected one session'
log=${output##*; see }
[[ "$log" == "$work/.git/autopilot/"*-phase-2-specs-001-a.log ]] || fail "session log: expected it in .git/autopilot, got '$log'"
grep -q 'session output' "$log" 2>/dev/null || fail "session log: expected the session's output in '$log'"

setup specs/001-a "$tasks_2_3"
status=0
output=$(cd "$work" && FAKE_LIMIT=2 FAKE_RESET=1000000000 PATH="$dir/bin:$PATH" FAKE_ORIGIN="$dir/origin.git" \
  FAKE_LOG="$dir/sessions" FAKE_SLEEPS="$dir/sleeps" CLAUDE="$fake" ./scripts/autopilot.sh 2>&1) || status=$?
sessions=$(sed -E 's/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/ID/g' "$dir/sessions")
[ "$status" = 0 ] || fail "usage limit: expected the run to finish, got $status: $output"
want="$(step_prompt specs/001-a 'Phase 2 of specs/001-a')
$resume_line
$resume_line
$(step_prompt specs/001-a 'Phase 3 of specs/001-a')"
[ "$sessions" = "$want" ] || fail "usage limit: expected the step resumed twice, got '$sessions'"
ids=$(grep -oE '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}' "$dir/sessions" | head -n 3 | sort -u | wc -l | tr -d ' ')
[ "$ids" = 1 ] || fail "usage limit: expected each resume to name the step's own session"
[ "$(cat "$dir/sleeps" 2>/dev/null)" = "60
60" ] || fail "usage limit: a reset time already past waits a minute, got '$(cat "$dir/sleeps" 2>/dev/null)'"
[[ "$output" == *'phase 2 specs/001-a stopped on a usage limit; resuming in 60 s'* ]] || fail "usage limit: expected the wait announced, got '$output'"
log=$(ls "$work"/.git/autopilot/*-phase-2-specs-001-a.log)
[ "$(grep -c 'session output' "$log")" = 3 ] || fail "usage limit: expected every attempt in the step's log"
grep -q 'usage limit reached' "$log" || fail 'usage limit: expected the limit message kept in the log'

setup specs/001-a "$tasks_2_3"
status=0
output=$(cd "$work" && FAKE_ERROR=1 PATH="$dir/bin:$PATH" FAKE_ORIGIN="$dir/origin.git" FAKE_LOG="$dir/sessions" \
  FAKE_SLEEPS="$dir/sleeps" CLAUDE="$fake" ./scripts/autopilot.sh 2>&1) || status=$?
[ "$status" = 1 ] || fail "other session error: expected exit 1, got $status"
[[ "$output" == *'phase 2 specs/001-a left main unchanged (session exit 1)'* ]] || fail "other session error: got '$output'"
[ "$(wc -l <"$dir/sessions" | tr -d ' ')" = 1 ] || fail 'other session error: expected no resume'
[ ! -e "$dir/sleeps" ] || fail 'other session error: expected no wait'

for gate in .claude/settings.json .githooks/pre-push; do
  for committed in '' 1; do
    case="$gate changed${committed:+ and committed} before a usage limit"
    setup specs/001-a "$tasks_2_3"
    status=0
    output=$(cd "$work" && FAKE_LIMIT=1 FAKE_GATE=$gate FAKE_GATE_COMMIT=$committed PATH="$dir/bin:$PATH" \
      FAKE_ORIGIN="$dir/origin.git" FAKE_LOG="$dir/sessions" FAKE_SLEEPS="$dir/sleeps" CLAUDE="$fake" \
      ./scripts/autopilot.sh 2>&1) || status=$?
    [ "$status" = 1 ] || fail "$case: expected exit 1, got $status"
    [[ "$output" == *'phase 2 specs/001-a changed .claude/ or .githooks/, so it is not resumed'* ]] ||
      fail "$case: got '$output'"
    [ "$(wc -l <"$dir/sessions" | tr -d ' ')" = 1 ] || fail "$case: expected no resume"
  done
done

setup specs/001-a "$tasks_2_3"
reset=$(($(date +%s) + 600))
output=$(cd "$work" && FAKE_LIMIT=1 FAKE_RESET=$reset PATH="$dir/bin:$PATH" FAKE_ORIGIN="$dir/origin.git" \
  FAKE_LOG="$dir/sessions" FAKE_SLEEPS="$dir/sleeps" CLAUDE="$fake" ./scripts/autopilot.sh 2>&1) || true
wait=$(cat "$dir/sleeps" 2>/dev/null)
[ "$wait" -ge 655 ] && [ "$wait" -le 660 ] || fail "usage limit: expected a wait until a minute after the reset, got '$wait'"

setup specs/001-a "$tasks_2_3"
output=$(cd "$work" && FAKE_LIMIT=1 PATH="$dir/bin:$PATH" FAKE_ORIGIN="$dir/origin.git" \
  FAKE_LOG="$dir/sessions" FAKE_SLEEPS="$dir/sleeps" CLAUDE="$fake" ./scripts/autopilot.sh 2>&1) || true
[ "$(cat "$dir/sleeps" 2>/dev/null)" = 1800 ] || fail "usage limit: expected half an hour with no reset time, got '$(cat "$dir/sleeps" 2>/dev/null)'"

decisions='# Decisions

## D-001 · Blocker · T002: a resolved blocker
- **Status**: resolved

## D-002 · Spec gap · T002: an open gap
- **Status**: open

## D-003 · Choice · T002: an accepted choice
- **Status**: accepted
'
setup specs/001-a "$tasks_2_3"
printf '%s' "$decisions" >"$work/specs/001-a/decisions.md"
commit_and_push "$work"
run
[ "$status" = 0 ] || fail "only a resolved blocker: expected exit 0, got $status: $output"
[[ "$output" == *'specs/001-a/decisions.md: 1 open'* ]] || fail "summary counts open entries, got '$output'"

setup specs/001-a "$tasks_2_3"
push_from_elsewhere specs/001-a/decisions.md "$decisions
## D-004 · Blocker · T002: needs a console
- **Status**: open
"
run
[ "$status" = 1 ] || fail "open blocker on main: expected exit 1, got $status"
[[ "$output" == *'specs/001-a/decisions.md: D-004 · Blocker · T002: needs a console'* ]] || fail "open blocker on main: expected it listed, got '$output'"
[ -z "$sessions" ] || fail "open blocker on main: expected no session, got '$sessions'"

setup specs/001-a "$tasks_2_3"
echo change >"$work/stray"
run
[ "$status" = 1 ] || fail "changes in the tree: expected exit 1, got $status"
[[ "$output" == *'the working tree has changes'* ]] || fail "changes in the tree: got '$output'"
[ -z "$sessions" ] || fail "changes in the tree: expected no session, got '$sessions'"

setup specs/001-a "$tasks_2_3"
status=0
output=$(cd "$work" && FAKE_LITTER=1 PATH="$dir/bin:$PATH" FAKE_ORIGIN="$dir/origin.git" FAKE_LOG="$dir/sessions" \
  FAKE_SLEEPS="$dir/sleeps" CLAUDE="$fake" ./scripts/autopilot.sh 2>&1) || status=$?
[ "$status" = 1 ] || fail "session leaves changes: expected exit 1, got $status"
[[ "$output" == *'the working tree has changes'* ]] || fail "session leaves changes: got '$output'"
[ "$(wc -l <"$dir/sessions" | tr -d ' ')" = 1 ] || fail 'session leaves changes: expected one session'

setup specs/001-a "$tasks_2_3"
run extra
[ "$status" = 2 ] || fail "unknown argument: expected exit 2, got $status"

if [ "$failures" -gt 0 ]; then
  echo "test-autopilot.sh: $failures failed"
  exit 1
fi
echo 'test-autopilot.sh: all passed'
