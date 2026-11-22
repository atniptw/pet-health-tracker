#!/usr/bin/env bash
# PreToolUse hook for the reviewer agents: allows only read-only git commands.
set -euo pipefail

command=$(jq -r '.tool_input.command // ""')
deny() {
  echo "Reviewers are read-only: Bash allows one git diff, log, show, status, ls-files, grep or blame command, with no redirects, pipes or command chaining. $1" >&2
  exit 2
}

# Each denial says what to send instead. Quotes don't protect these characters:
# the hook reads the command as one string.
case "$command" in
  *';'* | *'&'* | *$'\n'*) deny 'Send one git command per call, and the next one in its own call.' ;;
  *'\|'*) deny 'Give git grep one -e per alternative instead of A\|B: git grep -n -e A -e B.' ;;
  *'|'*) deny 'A | counts as a pipe even inside quotes. Send one git command per call; for alternatives in a pattern, give git grep one -e per alternative (git grep -n -e A -e B), or use the Grep tool.' ;;
  *'\'*) deny 'A backslash counts even inside quotes: use the Grep tool for a pattern that has one.' ;;
  *'>'* | *'<'*) deny '< and > count as redirects even inside quotes: use the Grep tool for a pattern that has them.' ;;
  # Expansion can build an option after this hook has read the command.
  *'`'* | *'$'*) deny 'Write the command out without $ or backticks.' ;;
  *'{'*) deny 'Braces can build an option after this hook has read the command: use the Grep tool for a pattern that has them.' ;;
esac
if printf '%s' "$command" | grep -Eq -e '^[[:space:]]*git[[:space:]]+-'; then
  deny 'Bash already runs in the repository: start with the subcommand, as in git diff --cached, with no -C or other option before it.'
fi
if ! printf '%s' "$command" | grep -Eq -e '^[[:space:]]*git[[:space:]]+(diff|log|show|status|ls-files|grep|blame)([[:space:]]|$)'; then
  case "$command" in
    cat* | sed* | head* | tail* | less* | more*) deny 'Use the Read tool to read a file, with an offset and limit for part of it.' ;;
    grep* | rg* | find* | ls*) deny 'Use the Grep tool to search, or Glob to list files.' ;;
  esac
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
