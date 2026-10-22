#!/usr/bin/env bash
# PreToolUse hook on Bash: denies git commit until every reviewer the staged
# change needs (scripts/required-reviewers.sh) has a stamp for exactly that
# change, left by review-stamp.sh when the reviewer passed it.
#
# The gate checks only the staged change, so a commit may use only options that
# commit exactly that, and only in this worktree.
set -euo pipefail

deny() {
  echo "Commit blocked: $1" >&2
  exit 2
}

input=$(cat)
if ! command=$(printf '%s' "$input" | jq -r '.tool_input.command // ""' 2>/dev/null); then
  case "$input" in *commit*) deny "jq couldn't read the command, so it may be a commit." ;; esac
  exit 0
fi

# Keeps each quoted argument one word, so user.name="A B" stays one value.
join_quoted() { perl -0pe 's/("(?:[^"\\]|\\.)*"|\x27[^\x27]*\x27)/(my $q = $1) =~ s{\s}{_}g; $q/ge'; }

# The command is read twice: with quotes dropped, which finds a commit inside
# bash -c "...", and with each quoted argument kept whole, which finds one
# after an option value with a space in it. Either reading counts.
# bash exits outright when . can't find its file, so check it first.
helpers="$(dirname "$0")/command-text.sh"
# shellcheck source=command-text.sh
if ! [ -r "$helpers" ] || ! . "$helpers" ||
  ! plain=$(printf '%s' "$command" | drop_messages | unquote) ||
  ! joined=$(printf '%s' "$command" | drop_messages | join_quoted | unquote); then
  case "$command" in *commit*) deny "the command couldn't be read, so it may be a commit." ;; esac
  exit 0
fi
text=$(printf '%s\n%s' "$plain" "$joined")

git_commit='(^|[^[:alnum:]_.-])git([[:space:]]+-[^[:space:]]+([[:space:]]+[^-[:space:]][^[:space:]]*)?)*[[:space:]]+commit([[:space:]]|$)'
printf '%s' "$text" | grep -Eq -e "$git_commit" || exit 0

# Claude Code lets a tool call through when its hook exits 1, so any failure
# from here on denies the commit instead.
trap 'deny "the review gate failed."' ERR

# Prints "option <token>" for each argument outside the allowed set, and
# "dir <path>" for each -C or cd target.
# Redirects are skipped with their targets: the shell still passes any words
# after them to git.
problems=$(printf '%s' "$text" | perl -0ne '
  s/\d*[<>]&\d*-?/ REDIRECT /g;
  s/&(>>?)/ $1 /g;
  while (/(?:^|[^\w.-])git((?:\s+-\S+(?:\s+[^-\s]\S*)?)*)\s+commit(?=\s|$)([^;&|)\n]*)/g) {
    my ($global, $args) = ($1, $2);
    my @g = split " ", $global;
    for my $i (0 .. $#g) { print "dir ", $g[$i + 1] // "", "\n" if $g[$i] eq "-C" }
    my @a = split " ", $args;
    while (@a) {
      my $t = shift @a;
      next if $t eq "REDIRECT";
      if ($t =~ /^\d*(?:>>?|<)$/) { shift @a; next }
      next if $t =~ /^\d*(?:>>?|<)/;
      if ($t =~ /^-[qsv]*m$/ || $t eq "--message" || $t eq "--message=") { shift @a; next }
      next if $t =~ /^-[qsv]+$/ || $t =~ /^--(?:quiet|signoff|verbose|amend|no-edit|allow-empty|dry-run|message=\S+)$/;
      print "option $t\n";
    }
  }
  print "dir $1\n" while /(?:^|[;&|(\n])\s*cd\s+(\S+)/g;
')

option=$(printf '%s\n' "$problems" | sed -n 's/^option //p' | head -1)
if [ -n "$option" ]; then
  deny "$option isn't allowed: the gate checks only the staged change. Stage what to commit and use git commit -m with -q, -s, -v, --amend, --no-edit, --allow-empty or --dry-run."
fi

top=$(git rev-parse --show-toplevel)
while IFS= read -r dir; do
  [ -n "$dir" ] || continue
  there=$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null) || deny "$dir isn't a git worktree, so the gate can't check the commit."
  [ "$there" = "$top" ] || deny "the commit would run in $there, but the gate checks $top."
done < <(printf '%s\n' "$problems" | sed -n 's/^dir //p')

cd "$top"
reviewers="$(dirname "$0")/../../scripts/required-reviewers.sh"
required=$("$reviewers") || deny 'scripts/required-reviewers.sh failed, so the reviewers this change needs are unknown.'
[ -n "$required" ] || exit 0
hashes=$("$reviewers" --hashes) || deny 'scripts/required-reviewers.sh --hashes failed.'
stamps=$(git rev-parse --git-path review-stamps)/stamps

missing=()
while IFS= read -r name; do
  hash=$(printf '%s\n' "$hashes" | awk -v name="$name" '$1 == name { print $2 }')
  stamp=$(cat "$stamps/$name" 2>/dev/null || true)
  [ -n "$hash" ] && [ "$stamp" = "$hash" ] || missing+=("$name")
done <<<"$required"

if [ "${#missing[@]}" -gt 0 ]; then
  deny "$(printf '%s ' "${missing[@]}")haven't passed the staged change. Run the targeted-review skill: a reviewer leaves a stamp when it ends with VERDICT: PASS, for the staged diff as it was when its run started."
fi
