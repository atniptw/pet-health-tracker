#!/usr/bin/env bash
# Prints the reviewer agents a diff needs, one name per line: each agent in
# .claude/agents whose Paths line matches a changed file. Arguments go to
# git diff (default --cached, the staged change).
#
# With --hashes, prints "<name> <hash>" for every agent instead, where the
# hash covers the staged diff of that agent's Paths. The commit gate compares
# these with the stamps reviewers leave when they pass.
#
# Agents are read from git, not the working tree: an agent counts if it is in
# the last commit or staged, with the names and Paths of both copies combined,
# so neither an unstaged edit nor a staged one can narrow which reviewers run.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

hashes=false
if [ "${1:-}" = --hashes ]; then
  if [ "$#" -ne 1 ]; then
    echo "usage: $0 --hashes" >&2
    exit 2
  fi
  hashes=true
  set -- --cached
fi
[ "$#" -gt 0 ] || set -- --cached

revisions=(:)
if git rev-parse -q --verify HEAD >/dev/null; then
  revisions+=(HEAD)
fi

list_agents() {
  for revision in "${revisions[@]}"; do
    if [ "$revision" = : ]; then
      git ls-files -z -- '.claude/agents/*.md'
    else
      git ls-tree -r -z --name-only "$revision" -- .claude/agents/
    fi
  done
}

names=$(
  list_agents | sort -zu | while IFS= read -r -d '' agent; do
    [[ "$agent" == *.md ]] || continue
    copies=$(for revision in "${revisions[@]}"; do
      git show "${revision%:}:$agent" 2>/dev/null || true
    done)
    paths=$(printf '%s\n' "$copies" | sed -n 's/^Paths: //p' | grep -o '`[^`]*`' | tr -d '`' | sort -u || true)
    if [ -z "$paths" ]; then
      echo "$agent has no Paths line" >&2
      exit 1
    fi
    # Pathspecs like :(glob)lib/** must reach git unexpanded.
    set -f
    # shellcheck disable=SC2086
    # set -e is off inside $(...), so a failing diff has to exit by hand.
    if $hashes; then
      diff=$(git diff "$@" -- $paths ':(exclude)lib/firebase_options.dart') || exit 1
      hash=$(printf '%s' "$diff" | git hash-object --stdin) || exit 1
      printf '%s\n' "$copies" | sed -n "s/^name: \(.*\)/\1 $hash/p"
    else
      changed=$(git diff --name-only "$@" -- $paths ':(exclude)lib/firebase_options.dart') || exit 1
      if [ -n "$changed" ]; then
        printf '%s\n' "$copies" | sed -n 's/^name: //p'
      fi
    fi
    set +f
  done
)
printf '%s\n' "$names" | sort -u | sed '/^$/d'
