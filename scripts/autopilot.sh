#!/usr/bin/env bash
# Runs an autonomous run (docs/dev-workflow/autonomous-runs.md): one fresh
# Claude Code session per step, from the first spec in specs/ that isn't built.
# A step plans a spec that has no tasks.md, or builds the first phase of its
# tasks.md with an unticked task. The run stops when every task is ticked, when
# a decisions.md on main has an open blocker, or when a step leaves origin/main
# where it was. It switches this checkout to origin/main before each step, so
# it needs a clean tree. A session that stops on a usage limit is resumed once
# the limit resets, unless it changed .claude/ or .githooks/, which stops the
# run. --next prints the next step and starts nothing.
set -euo pipefail
cd "$(dirname "$0")/.."
claude=${CLAUDE:-claude}

# Prints "plan <spec dir>" or "phase <n> <spec dir>", or nothing when every
# spec is built.
next_step() {
  local spec phase
  for spec in specs/[0-9][0-9][0-9]-*/; do
    [ -d "$spec" ] || continue
    spec=${spec%/}
    if [ ! -e "$spec/tasks.md" ]; then
      echo "plan $spec"
      return
    fi
    phase=$(awk '/^## Phase [0-9]+(:|$)/ { p = $3; sub(/:$/, "", p) }
      /^- \[ \] / && p != "" { print p; exit }' "$spec/tasks.md")
    if [ -n "$phase" ]; then
      echo "phase $phase $spec"
      return
    fi
  done
}

# Prints each open blocker as "<decisions file>: <entry heading>".
open_blockers() {
  local file
  for file in specs/*/decisions.md; do
    [ -e "$file" ] || continue
    awk -v file="$file" '
      /^## D-/ { heading = substr($0, 4); blocker = ($0 ~ /^## D-[0-9]+ · Blocker ·/) }
      /^- \*\*Status\*\*: open$/ && blocker { print file ": " heading }' "$file"
  done
}

# Prints how many entries each decisions.md has open for review.
summary() {
  local file
  for file in specs/*/decisions.md; do
    [ -e "$file" ] || continue
    echo "$file: $(grep -c '^- \*\*Status\*\*: open$' "$file" || true) open"
  done
}

if [ "${1:-}" = --next ]; then
  next_step
  exit 0
fi
if [ $# -gt 0 ]; then
  echo 'usage: scripts/autopilot.sh [--next]' >&2
  exit 2
fi

log_dir="$(cd "$(git rev-parse --git-common-dir)" && pwd)/autopilot"
mkdir -p "$log_dir"
attempt_out="$log_dir/attempt.out"

# Runs claude once with the given arguments for the step's $spec, keeping its
# output in $attempt_out and adding it to $log; sets $status.
attempt() {
  status=0
  SPECIFY_FEATURE_DIRECTORY="$spec" SPECIFY_FEATURE_NO_PERSIST=1 \
    "$claude" "$@" --permission-mode auto --permission-prompts none --output-format json \
    >"$attempt_out" 2>&1 || status=$?
  cat "$attempt_out" >>"$log"
}

# True when the last attempt ended in an error that names a usage limit.
hit_usage_limit() {
  grep -qE '"is_error": *true' "$attempt_out" &&
    grep -qiE 'usage limit|limit reached|hit your (usage )?limit' "$attempt_out"
}

# Prints the seconds to wait before resuming: until a minute after the reset
# time when the message gives one as "|<epoch seconds>", or half an hour.
limit_wait() {
  local reset now
  reset=$(grep -oE '\|[0-9]{10}' "$attempt_out" | tail -n 1 | tr -d '|' || true)
  now=$(date +%s)
  if [ -z "$reset" ]; then
    echo 1800
  elif [ "$reset" -gt "$now" ]; then
    echo $((reset - now + 60))
  else
    echo 60
  fi
}

# True when this checkout's .claude/ and .githooks/, committed or not, match
# origin/main's, so a resumed session loads only the reviewed hooks and
# settings.
gates_unchanged() {
  git diff --quiet origin/main -- .claude .githooks &&
    [ -z "$(git status --porcelain -- .claude .githooks)" ]
}

while :; do
  if [ -n "$(git status --porcelain)" ]; then
    echo 'autopilot: the working tree has changes; commit or remove them first' >&2
    summary
    exit 1
  fi
  git fetch -q origin
  git switch -q --detach origin/main
  blockers=$(open_blockers)
  if [ -n "$blockers" ]; then
    printf 'autopilot: stopped on an open blocker\n%s\n' "$blockers"
    summary
    exit 1
  fi
  step=$(next_step)
  if [ -z "$step" ]; then
    echo 'autopilot: every spec is built'
    summary
    exit 0
  fi
  read -r kind phase spec <<<"$step"
  if [ "$kind" = plan ]; then
    spec=$phase
    prompt="Autonomous run. Plan $spec, as docs/dev-workflow/autonomous-runs.md says."
  else
    prompt="Autonomous run. Phase $phase of $spec, as docs/dev-workflow/autonomous-runs.md says."
  fi
  log="$log_dir/$(date +%Y%m%d-%H%M%S)-$(echo "$step" | tr ' /' '--').log"
  before=$(git rev-parse origin/main)
  echo "autopilot: $step (log: $log)"
  session=$(uuidgen | tr '[:upper:]' '[:lower:]')
  attempt -p "$prompt" --session-id "$session"
  while hit_usage_limit; do
    if ! gates_unchanged; then
      echo "autopilot: $step changed .claude/ or .githooks/, so it is not resumed; see $log" >&2
      summary
      exit 1
    fi
    wait=$(limit_wait)
    echo "autopilot: $step stopped on a usage limit; resuming in $wait s"
    sleep "$wait"
    attempt -p 'Autonomous run. A usage limit stopped this step; carry on from where it stopped.' \
      --resume "$session"
  done
  git fetch -q origin
  if [ "$(git rev-parse origin/main)" = "$before" ]; then
    echo "autopilot: $step left main unchanged (session exit $status); see $log" >&2
    summary
    exit 1
  fi
done
