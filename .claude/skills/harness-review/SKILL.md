---
name: harness-review
description: Look back over the phase that just merged for what worked and what cost time in the Claude Code setup (agents, skills, hooks, settings, scripts, git hooks, CI, plugins, MCP servers), check Claude Code's releases for features that would help, and propose changes for the user to decide. Builds nothing. Use at the start of the session after a phase merges, before the next phase starts, and whenever the user asks to review the harness.
---

# Harness review

The harness is everything around the code that shapes how the work gets done: the reviewer agents in `.claude/agents/`, the skills in `.claude/skills/`, the hooks and settings in `.claude/`, the scripts in `scripts/` and `tool/`, the git hooks in `.githooks/`, CI in `.github/`, and Claude Code plugins and MCP servers. The review covers one phase: the phase whose pull request merged last. It only reads and reports. The user decides what gets built.

## Steps

### 1. Gather what happened
For the phase that merged last:
- its pull request, commits and CI runs (`gh api repos/{owner}/{repo}/pulls/{n}`, `.../pulls/{n}/commits`, `.../actions/runs`)
- its rows in the feature's `build-log.md`: review rounds, reviewer FAILs, clarify questions, stop rules, where the user stepped in
- the project's session transcripts in `~/.claude/projects/` from while the phase was built: denied commands, repeated permission prompts, commands run again and again, checks that failed
- the installed Claude Code version (`claude --version`) and its changelog entries released since the phase's first commit, read with the `web-fetch` agent from `https://raw.githubusercontent.com/anthropics/claude-code/main/CHANGELOG.md`

### 2. Note what worked
Each place where the harness caught a real problem before it reached `main`, with the evidence: a reviewer finding that was right and fixed, a check or hook that stopped a mistake.

### 3. Note what cost time or let something through
Each with its evidence from this phase:
- the same manual steps or commands repeated across tasks
- a hook or the commit gate denying something legitimate, or a permission prompt for a safe command that kept coming back
- a reviewer finding that was wrong, or the same finding from several reviewers (overlapping checklists)
- a problem that got past the reviewers and checks and was caught later by CI, the user or a tester
- a check that was slow, flaky or failed for a reason unrelated to the change
- instructions in `CLAUDE.md`, the constitution or a skill that were unclear, out of date or not followed

Leave out anything without evidence from this phase.

### 4. Match new Claude Code features
From the changelog entries in step 1, keep only the features that would fix something from step 3 or replace a part of the harness with less of it. Name the version that added each one.

### 5. Report
Tell the user, in one message:
- what worked
- each proposal: the problem, its evidence, the change (which agent, skill, script, hook, setting, plugin, MCP server or CI step), and whether it relaxes a check, a gate or a permission, adds a dependency, or amends the constitution
- that nothing was found, if so

Change nothing. The proposals the user picks become tasks in `docs/dev-workflow/tasks.md`, each built as one commit through steps 3 and 4 of the constitution's workflow.
