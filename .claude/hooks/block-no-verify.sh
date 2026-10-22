#!/usr/bin/env bash
# PreToolUse hook on Bash: denies commands that skip or weaken the git hooks.
# It guards against taking a shortcut, not against a determined attacker: CI
# runs every check again before anything deploys.
set -euo pipefail

# shellcheck source=command-text.sh
. "$(dirname "$0")/command-text.sh"

command=$(jq -r '.tool_input.command // ""')
without_messages=$(printf '%s' "$command" | drop_messages)
text=$(printf '%s' "$without_messages" | unquote)

matches() { printf '%s' "$text" | grep -Eiq -e "$1"; }

end='([[:space:];&|)]|$)'
git="git([[:space:]]+[^[:space:];&|]+)*[[:space:]]+"

# Expansion ($, braces, backslashes) can build a flag after this hook has read
# the command, so git commit, git push and COVERAGE_ variables must be literal.
expands_guarded_command() {
  printf '%s' "$without_messages" | grep -Eiq -e "${git}(commit|push)${end}|COVERAGE_" &&
    printf '%s' "$without_messages" | grep -q -e '[$\\{]'
}

# git accepts any unambiguous prefix of a long option; --no-veri is the shortest.
skips_verify() { matches "${git}(commit|push)${end}.*--no-veri"; }

skips_commit_hooks() {
  matches "${git}commit${end}([^;&|]*[[:space:]])?-[a-zA-Z]*n[a-zA-Z]*${end}"
}

# An alias can hide either flag from the checks above.
aliases_commit_or_push() {
  matches "alias\.[^[:space:]=]+[[:space:]=]+[^;&|]*(commit|push)${end}"
}

# send-pack updates a remote without running the pre-push hook.
sends_pack() { matches "${git}send-pack${end}"; }

# Setting core.hooksPath to anything but .githooks, or unsetting it. Reading or
# searching for it is fine.
changes_hooks_path() {
  printf '%s' "$command" | grep -Eiq -e "core\.hookspath[[:space:]=]+(\"\"|'')" && return 0
  printf '%s' "$text" | perl -0ne '
    my $other_value = qr/[\s=]+(?!\.githooks(?:[\s;&|)<>]|$)|\d*[<>])[^\s;&|)<>-]/;
    exit(/\bgit\b[^;&|]*?\s(?:config\b[^;&|]*?\s|-c\s+)core\.hookspath$other_value/i
      || /(?:--unset(?:-all)?|\bunset)\s+core\.hookspath/i
      || /GIT_CONFIG_(?:KEY_\d+|PARAMETERS)=\S*core\.hookspath/i ? 0 : 1);
  '
}

# coverage.sh reads its files from COVERAGE_ROOT, so setting it fakes the check.
fakes_coverage() { matches 'COVERAGE_ROOT[[:space:]]*='; }

if expands_guarded_command || skips_verify || skips_commit_hooks || aliases_commit_or_push ||
  sends_pack || changes_hooks_path || fakes_coverage; then
  echo "Blocked: this skips or weakens the git hooks (--no-verify, commit -n, a commit or push alias, git send-pack, changing core.hooksPath, setting COVERAGE_ROOT, or building git commit/push with \$, braces or backslashes). Fix what the checks report instead." >&2
  exit 2
fi
