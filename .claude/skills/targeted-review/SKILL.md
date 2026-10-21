---
name: targeted-review
description: Review a change with the narrow reviewer agents in .claude/agents (clean-code, comment-hygiene, docs-sync, security, test-quality, release-safety, flutter-lifecycle, scope-guard), run in parallel, then consolidate into one punch list. Use before every commit, and whenever the user asks to review code or check a diff.
---

# Targeted review

Each reviewer agent owns one concern and checks it against a fixed checklist. Every reviewer a change needs must pass before the change is committed.

## Steps

### 1. Scope the change
Default to the staged change. Stage exactly what will be committed first, because the reviewers read `git diff --cached`. If the user names a commit range, a branch or a PR, review that instead and pass the range to every reviewer.

### 2. Find the required reviewers
Run `./scripts/required-reviewers.sh`. For a range, run `./scripts/required-reviewers.sh <from> <to>`. It prints every agent whose `Paths:` line matches a changed file. Run exactly those: don't drop one because the change looks unrelated to it, and don't add others. If it prints nothing, the change needs no review.

### 3. Launch them in parallel
Send one message with one `Agent` call per reviewer, with `subagent_type` set to the reviewer's name. Each prompt says:
- **What the change is for**, in a sentence or two: what the user asked for and which decisions or design README it implements. `scope-guard` compares the change to this, and the others use it to understand intent.
- **Where to look**, if not the staged diff: the commit range or files.
- **What to look at hardest**, if you know: the part most likely to be wrong, phrased so the reviewer has to trace the code ("walk through what happens when a member leaves while the sheet is open").

The agents already have their checklist and the report format (the `review-protocol` skill), so don't repeat either. Tell the user in one line which reviewers are running.

### 4. Consolidate
As reports arrive, tell the user briefly which passed and which failed. When all are back, give one punch list ordered by severity. Merge findings that several reviewers report and say they converged, because that's a strong signal. Don't relay the reports one by one.

Check each finding before acting on it. A reviewer can be wrong, can have read an older version of a file, or can flag something the user decided. If you disagree with a finding, tell the user why rather than quietly skipping it.

### 5. Fix and re-check
Fix the findings, with tests first where the fix changes behavior. Stage the fixes and run `./scripts/check.sh`.

Then run `./scripts/required-reviewers.sh` again. Every listed reviewer whose paths the fixes touched has to pass the new staged diff, including reviewers that passed before. To save time, use `SendMessage` to continue the reviewer's existing agent with a short note on what changed, rather than starting a new one. A reviewer whose paths the fixes didn't touch keeps its pass.

### 6. Commit
Commit only when every required reviewer's latest verdict is `VERDICT: PASS` for the staged diff. If a finding needs the user's decision, ask before committing.
