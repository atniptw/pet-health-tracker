#!/usr/bin/env bash
# SubagentStart, PostToolUse (SubagentHandback) and SubagentStop hook: records
# reviewer verdicts as stamps for the commit gate (review-gate.sh).
#
# A stamp holds the hash of the staged diff of a reviewer's Paths when its run
# started (scripts/required-reviewers.sh --hashes), and is written only when
# the run's report ends in "VERDICT: PASS". Any other ending removes the
# reviewer's stamp. The gate compares the stamp with the staged diff at commit
# time, so anything staged after the run started needs another run. A change
# staged and then unstaged during a run goes unnoticed. Stamps live in the git
# directory, so they are never committed.
set -euo pipefail

input=$(cat)
field() { printf '%s' "$input" | jq -r "$1 // \"\""; }
event=$(field .hook_event_name)
type=$(field .agent_type)
id=$(field .agent_id | tr -c 'A-Za-z0-9_-' _)
[ -n "$type" ] && [ "$id" != _ ] && [ -n "$id" ] || exit 0

cd "$(git rev-parse --show-toplevel)"
dir=$(git rev-parse --git-path review-stamps)
reviewers="$(dirname "$0")/../../scripts/required-reviewers.sh"

# The hash of this agent's part of the staged diff, or nothing if it isn't a
# reviewer.
hash_of() { "$reviewers" --hashes | awk -v name="$1" '$1 == name { print $2 }'; }

case "$event" in
  SubagentStart)
    hash=$(hash_of "$type")
    [ -n "$hash" ] || exit 0
    mkdir -p "$dir/runs" "$dir/reports" "$dir/stamps"
    printf '%s\n' "$hash" >"$dir/runs/$id"
    rm -f "$dir/reports/$id"
    ;;
  PostToolUse)
    [ "$(field .tool_name)" = SubagentHandback ] && [ -f "$dir/runs/$id" ] || exit 0
    field .tool_input.message >"$dir/reports/$id"
    ;;
  SubagentStop)
    [ -f "$dir/runs/$id" ] || exit 0
    started=$(cat "$dir/runs/$id")
    if [ -f "$dir/reports/$id" ]; then
      report=$(cat "$dir/reports/$id")
    else
      report=$(field .last_assistant_message)
    fi
    rm -f "$dir/runs/$id" "$dir/reports/$id"
    verdict=$(printf '%s\n' "$report" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e '/^$/d' | tail -1)
    if [ "$verdict" = 'VERDICT: PASS' ]; then
      printf '%s\n' "$started" >"$dir/stamps/$type"
    else
      rm -f "$dir/stamps/$type"
    fi
    ;;
esac
