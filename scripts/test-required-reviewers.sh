#!/usr/bin/env bash
# Tests for scripts/required-reviewers.sh, run in a scratch git repo with
# made-up agents, plus a check that every real agent has a name and Paths line.
set -euo pipefail
cd "$(dirname "$0")/.."
script="$PWD/scripts/required-reviewers.sh"

failures=0
fail() {
  echo "FAIL required-reviewers.sh: $1"
  failures=$((failures + 1))
}

for agent in .claude/agents/*.md; do
  grep -q '^name: ' "$agent" || fail "$agent has no name"
  grep -q '^Paths: `' "$agent" || fail "$agent has no Paths line"
done

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
printf -- '---\nname: rules-reviewer\n---\n\nPaths: `firestore.rules` `:(glob)docs/**`\n' >.claude/agents/b.md
printf 'notes\n' >.claude/agents/notes.txt
git add .claude && git commit -qm agents

expect() {
  local label=$1 want=$2 got
  shift 2
  got=$("$script" "$@" | tr '\n' ' ')
  [ "$got" = "$want" ] || fail "$label: expected '$want', got '$got'"
}

expect 'nothing staged' ''

echo x >lib/a.dart && git add lib/a.dart
expect 'a lib file' 'lib-reviewer '

echo x >firestore.rules && git add firestore.rules
expect 'lib and rules' 'lib-reviewer rules-reviewer '
git commit -qm both

echo x >docs/plan.md && git add docs/plan.md
expect 'a docs file' 'rules-reviewer '
git commit -qm docs

echo x >lib/firebase_options.dart && git add lib/firebase_options.dart
expect 'only the generated file' ''
git commit -qm generated

echo y >>lib/a.dart
expect 'an unstaged change' ''
git checkout -q -- lib/a.dart

echo x >README.md && git add README.md
expect 'a file no agent covers' ''

expect 'a commit range' 'lib-reviewer rules-reviewer ' HEAD~3 HEAD~2
git rm -q --cached README.md

# The agents come from git (the last commit and the staged copy), not from
# unstaged edits, so a reviewer can't be dropped by editing its file.
echo y >>lib/a.dart && git add lib/a.dart
sed -i.bak 's/^Paths: .*/Paths: `nothing`/' .claude/agents/a.md
expect 'an unstaged edit to an agent' 'lib-reviewer '
git add .claude/agents/a.md
expect 'a staged edit that narrows an agent' 'lib-reviewer '
git checkout -q HEAD -- .claude/agents/a.md
rm .claude/agents/a.md
expect 'an unstaged deleted agent' 'lib-reviewer '
git checkout -q -- .claude/agents/a.md
printf -- '---\nname: new-reviewer\n---\n\nPaths: `:(glob)lib/**`\n' >.claude/agents/d.md
git add .claude/agents/d.md
expect 'an agent added in the same change' 'lib-reviewer new-reviewer '
git rm -q --cached .claude/agents/d.md && rm .claude/agents/d.md
printf -- '---\nname: rules-reviewer\n---\n\nPaths: `firestore.rules` `:(glob)docs/**` `:(glob)lib/**`\n' >.claude/agents/b.md
git add .claude/agents/b.md
expect 'a staged edit that widens an agent' 'lib-reviewer rules-reviewer '
git checkout -q HEAD -- .claude/agents/b.md
printf -- '---\nname: rules-reviewer\n---\n\nPaths: `:(glob)lib/**`\n' >.claude/agents/a.md
git add .claude/agents/a.md
expect 'a staged edit that renames an agent' 'lib-reviewer rules-reviewer '
git checkout -q HEAD -- .claude/agents/a.md

# An agent file whose name has a space is still read.
printf -- '---\nname: spaced-reviewer\n---\n\nPaths: `:(glob)lib/**`\n' >'.claude/agents/e f.md'
git add '.claude/agents/e f.md'
expect 'an agent file name with a space' 'lib-reviewer spaced-reviewer '
git rm -q --cached '.claude/agents/e f.md' && rm '.claude/agents/e f.md'

# An agent without a Paths line is an error, not a reviewer that never runs.
printf -- '---\nname: broken\n---\n\nPaths are missing.\n' >.claude/agents/g.md
git add .claude/agents/g.md
"$script" >/dev/null 2>&1 && fail 'an agent without Paths: expected an error'
git rm -q --cached .claude/agents/g.md && rm .claude/agents/g.md

# A git diff that fails is an error, not an empty list.
"$script" no-such-commit HEAD >/dev/null 2>&1 && fail 'a bad commit range: expected an error'
printf -- '---\nname: lib-reviewer\n---\n\nPaths: `:(glob)lib/**` `:(bogus)x`\n' >.claude/agents/a.md
git add .claude/agents/a.md
"$script" >/dev/null 2>&1 && fail 'a malformed pathspec: expected an error'

if [ "$failures" -gt 0 ]; then
  echo "$failures required-reviewers test(s) failed"
  exit 1
fi
echo 'required-reviewers tests passed'
