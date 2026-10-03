---
name: targeted-review
description: Review recently changed code by splitting it into distinct areas of concern and reviewing each with its own parallel subagent, then consolidating into one punch list. Use whenever the user asks to review code, check a diff, or "spin up agents to review" — especially right after a feature slice is finished. Prefer this over a single monolithic review pass in this repo.
---

# Targeted review

A single agent reviewing an entire diff tends to skim: it gives security rules,
state management, widget lifecycle, and platform conventions the same shallow
pass, and important findings get diluted by whatever's easiest to notice. This
skill instead splits the diff into a handful of **distinct concern areas** and
gives each one its own subagent with a narrow, concrete brief — the same depth
of attention a human reviewer would give if they specialized in just that one
thing.

## Steps

### 1. Scope the review

Default to the working tree's uncommitted/staged changes (`git status`,
`git diff HEAD`). If the user names a different target (a PR, a branch, a
path), use that instead.

### 2. Pick targets from what actually changed — don't reuse a fixed list

Look at the touched files and find the natural seams. Concern areas exist
because different kinds of code fail in different ways and need different
questions asked of them — not because a checklist says so. For this Flutter +
Firebase project, recurring seams tend to be:

- **Security rules** (`firestore.rules`) — privilege escalation, missing field
  validation, rule/doc-model mismatches.
- **Data & state layer** (repositories, models, Riverpod providers) — race
  conditions, stream lifecycle, provider disposal, stale data across identity
  changes.
- **UI widget lifecycle** (screens, controllers) — unguarded `setState` after
  dispose, double-submit, dead-end error states.
- **Platform/modern-conventions** (theming, `MainActivity`/`Info.plist`,
  manifests) — safe-area/edge-to-edge, dark mode, other platform defaults that
  silently regress.

But treat that as a starting point, not the permanent list. A diff that adds a
background sync job needs an "offline/retry behavior" target; one that only
touches copy needs no security target at all. If a diff only touches one area,
one subagent is correct — don't invent extra targets to hit a quota. If two
areas are small enough that one careful read covers both, merge them.

### 3. Decide how each subagent gets its context

- If you (the current conversation) just wrote or discussed this code, use
  `subagent_type: "fork"` — it inherits full context for free, so the review
  prompt only needs to say what to check, not re-explain what was built.
- If the code is unfamiliar or from an earlier session, spawn fresh agents
  (`general-purpose` or the project's usual review agent) that read the diff
  themselves — give them the file paths and enough background to get oriented.

### 4. Write a narrow, concrete prompt per target

A vague "review this file for issues" produces vague findings. For each
target, give the subagent:

- The exact files in scope for that target (and which files are *out* of
  scope — another agent owns those).
- Specific, concrete questions to check — things you already suspect might be
  wrong, phrased so the agent has to trace the actual code rather than
  pattern-match ("walk through what happens when X" beats "check for bugs").
- An explicit instruction to report only real, concrete findings (a genuine
  exploit path, crash, data-loss, or documented-behavior violation) and skip
  style nits, returning just the findings (file:line, what goes wrong, how it's
  triggered) without preamble, so they stay scannable.
- For a hobby/POC project, an explicit note not to flag missing
  polish/features as bugs, so the agent doesn't pad the report with noise.

### 5. Launch all targets in parallel

One message, one `Agent` call per target — not sequential calls. Give the
user a one-line summary of what each agent is covering before you move on.

### 6. Consolidate, don't relay

As each agent's completion notification arrives, you may give the user a
short interim ping if a real finding lands — but the actual deliverable is one
**consolidated punch list** once everything is back, findings ordered
roughly by severity/actionability, duplicate or overlapping findings merged
(different agents sometimes converge on the same bug from different angles —
call that out, it's a good corroboration signal, not noise). Don't leave the
user to mentally merge four separate reports.

### 7. Offer next steps

After the punch list, ask whether to apply fixes now (bundle the small,
well-understood ones) versus leaving something as a noted follow-up (an
unconfirmed/hard-to-verify finding is worth a manual test rather than a
guessed fix).
