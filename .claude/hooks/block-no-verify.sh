#!/usr/bin/env bash
# PreToolUse hook on Bash: denies git commands that skip the git hooks.
set -euo pipefail

command=$(jq -r '.tool_input.command // ""')
# Quoted text (commit messages) may mention the flags without using them.
unquoted=$(printf '%s' "$command" | sed -E "s/'[^']*'//g; s/\"[^\"]*\"//g")

matches() { printf '%s' "$unquoted" | grep -Eq -e "$1"; }

end='([[:space:];&|)]|$)'
git_opts='([[:space:]]+-[^[:space:]]+([[:space:]]+[^-[:space:]][^[:space:]]*)?)*'
git="git${git_opts}[[:space:]]+"

if matches "${git}(commit|push)${end}.*--no-verify${end}" ||
  matches "${git}commit${end}([^;&|]*[[:space:]])?-[a-zA-Z]*n[a-zA-Z]*${end}" ||
  matches "core\.hooksPath[[:space:]=]+[^[:space:].]" ||
  matches "core\.hooksPath[[:space:]=]+\.[^g]" ||
  printf "%s" "$command" | grep -Eq -e "core\.hooksPath[[:space:]=]+(\"\"|'')" ||
  matches "--unset(-all)?[[:space:]]+core\.hooksPath"; then
  echo "Blocked: this skips the git hooks (--no-verify, commit -n, or changing core.hooksPath). Fix what the checks report instead." >&2
  exit 2
fi
