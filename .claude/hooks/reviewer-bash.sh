#!/usr/bin/env bash
# PreToolUse hook for the reviewer agents: allows only read-only git commands.
set -euo pipefail

command=$(jq -r '.tool_input.command // ""')
deny() {
  echo "Reviewers are read-only: Bash allows one git diff, log, show, status, ls-files, grep or blame command, with no redirects, pipes or command chaining. $1" >&2
  exit 2
}

case "$command" in
  *'>'* | *'<'* | *'|'* | *';'* | *'&'* | *'`'* | *$'\n'*) deny 'Run one command at a time.' ;;
  # Expansion can build an option after this hook has read the command.
  *'$'* | *'{'* | *'\'*) deny 'Write the command out without $, braces or backslashes.' ;;
esac
if ! printf '%s' "$command" | grep -Eq -e '^[[:space:]]*git[[:space:]]+(diff|log|show|status|ls-files|grep|blame)([[:space:]]|$)'; then
  deny 'Use Read, Grep or Glob for anything else.'
fi
# Options that write files or run other programs: --output, --ext-diff, --exec and
# -O/--open-files-in-pager. The shell drops quotes before git reads them, git
# accepts any unambiguous prefix of a long option, and -O can sit in a group
# of short flags.
unquoted=$(printf '%s' "$command" | tr -d "\"'\\\\")
if printf '%s' "$unquoted" | grep -Eq -e '(^|[[:space:]])(-[a-zA-Z]*O|--op|--ou|--ext|--exe)'; then
  deny 'That option writes files or runs a program.'
fi
