---
name: harness-review
description: Look back over a merged feature for friction in the Claude Code harness (agents, skills, scripts, hooks, settings, plugins, MCP servers and CI), build the clear-cut improvements and propose the rest. Use after each feature merges to main, and whenever the user asks to review or improve the harness.
---

# Harness review

The harness is everything around the code that shapes how the work gets done: the reviewer agents in `.claude/agents/`, the skills in `.claude/skills/`, the hooks and settings in `.claude/`, the scripts in `scripts/` and `tool/`, the git hooks in `.githooks/`, CI in `.github/`, and Claude Code plugins and MCP servers. The review finds where the harness cost time or let a problem through while building the feature, and fixes it.

## Steps

### 1. Gather what happened
Look at the feature that just merged:
- its commits on `main` (`git log`), and its `spec.md`, `plan.md` and `tasks.md`
- this conversation, and the project's session transcripts in `~/.claude/projects/` from while the feature was built
- the pull request and its CI runs (`gh pr view`, `gh run list`)

### 2. Find the friction
Note each place where the harness cost time or missed something, with the evidence for it:
- the same manual steps or commands repeated across tasks, which a script, skill or hook could do
- a hook or the commit gate denying something legitimate, or a permission prompt for a safe command that keeps coming back
- a reviewer finding that was wrong, or one that several reviewers reported (overlapping checklists)
- a problem that got past the reviewers and checks, and was caught later by CI, the user or a tester
- a check that was slow, flaky or failed for a reason unrelated to the change
- instructions in `CLAUDE.md`, the constitution or a skill that were unclear, out of date or ignored

Leave out anything without evidence from this feature.

### 3. Sort the improvements
For each one, name the change: a new or changed agent, skill, script, hook, setting, plugin or CI step. It is **clear-cut** when all of these hold:
- it is one small commit
- it doesn't relax a check, a gate or a permission
- it doesn't add a blocking reviewer or hook, a plugin, an MCP server or a dependency
- it doesn't amend the constitution

Everything else needs the user's decision.

### 4. Build the clear-cut ones
Commit and merge them as in steps 3 and 4 of the constitution's workflow, on a branch from `main`: tests for any script or hook change, `./scripts/check.sh`, the `targeted-review` skill, one commit each, and a pull request.

### 5. Report
Tell the user what was built, with the commits, and list the other improvements with the evidence and the change for each, so they can pick which to build. If the review found nothing, say so.
