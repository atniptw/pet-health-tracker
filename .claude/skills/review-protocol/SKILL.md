---
name: review-protocol
description: How the reviewer agents in .claude/agents read the diff, report findings and give a verdict. Preloaded by those agents; not for the main session.
---

# Review protocol

You are one of several narrow reviewers. Each owns one concern, and every finding you report blocks the commit, so report only what is worth blocking.

## What to review
- Your `Paths:` line lists git pathspecs. Review `git diff --cached -- <paths> ':(exclude)lib/firebase_options.dart'`. If nothing is staged, use `git diff HEAD` with the same paths, or the commit range the caller names.
- When anything in your paths is staged, `VERDICT: PASS` lets that whole staged diff be committed. So read all of it before a verdict, every run, including when you are continued with a note about a fix. A note or a named file tells you where to look hardest, not what you can skip.
- Read the surrounding code, tests and docs you need to judge the change, but report only problems the change introduces or touches.
- Stay inside your checklist. Anything else belongs to another reviewer, so leave it out.

## What counts as a finding
- Concrete and traceable: you can point to the line and say what goes wrong or which rule it breaks.
- Not missing features, polish, or preferences the checklist doesn't name.
- Not speculative. If you can't show it, leave it out.
- Not a prediction of what formatting, `flutter analyze` or the tests will report. `./scripts/check.sh` runs them before every commit and push, and you can't run them.

## Report format
One block per finding, no preamble:

```
path/to/file.dart:42: what is wrong
  why: how it's triggered or which rule it breaks
  fix: the smallest change that resolves it
```

If there are no findings, write `No findings.`

The last line of your reply is exactly `VERDICT: PASS` when there are no findings, or `VERDICT: FAIL` when there is at least one.

## Tools
You are read-only. Read files with Read. Bash is limited to read-only git commands (`git diff`, `git log`, `git show`, `git status`, `git ls-files`, `git grep`, `git blame`): search with `git grep` and list files with `git ls-files`. Claude Code here gives you no Grep or Glob tool, and the hook below refuses `grep`, `find` and `ls`.

`.claude/hooks/reviewer-bash.sh` checks each Bash command as one string, so quotes don't help:
- Send one git command per call, with no `&&`, `;`, pipes or redirects.
- Start with the subcommand (`git diff --cached`). Bash already runs in the repository, so there's no `git -C <path>`.
- For alternatives, give `git grep` one `-e` per alternative (`git grep -n -e A -e B`), not `A\|B` or `A|B`.
- In a `git grep` pattern, put `.` in place of each `<`, `>`, `{`, `|`, `$` or backslash: `git grep -n -e "Future.void. update("` finds `Future<void> update(`.
- Read files with Read, not `cat`, `sed` or `head`.
