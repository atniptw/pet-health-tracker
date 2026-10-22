#!/usr/bin/env bash
# Sourced by the hooks that read Bash commands (block-no-verify.sh and
# review-gate.sh), so both see a command the same way.

# Prints the command with the value of every git commit -m or --message
# replaced by MSG, heredoc form included: messages may mention flags and
# commands without running them.
drop_messages() {
  perl -0pe '
    my $quoted = qr{"\$\(cat\s+<<-?\x27?(\w+)\x27?\n.*?\n\g{-1}\n\)"|"(?:[^"\\]|\\.)*"|\x27[^\x27]*\x27}s;
    1 while s/(git(?:\s+[^\s;&|]+)*?\s+commit\b[^;&|]*?(?:^|\s)(?:-[a-zA-Z]*m|--message=?))\s*$quoted/$1 MSG/s;
  '
}

# Drops quotes and backslashes, which the shell removes before git reads its
# arguments, so `"--no-verify"`, `commit\ -n` and `bash -c "git commit"` read
# as what runs.
unquote() { tr -d "\"'\\\\"; }
