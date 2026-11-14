# Feature Specification: Development workflow: reviewers and gates

**Status**: Shipped | **Created**: 2026-10-21

## Overview
Every push to `main` ships to testers, so each commit has to pass checks that can't be skipped. Anything a script can measure goes in `scripts/check.sh`, so it applies to people, Claude and CI alike. Questions that need judgment go to narrow reviewer agents. Claude Code hooks decide which reviewers a commit needs, and block the commit until each of them passes.

## Decisions
- Review runs on every commit, not every push.
- All reviewers block: a `FAIL` verdict stops the commit until it's fixed.
- Limits: 300 lines per file, 40 per function. Current offenders go in a baseline and get refactored in separate commits.
- All eight reviewers in [plan.md](plan.md) are in, including `test-quality`, `release-safety`, `flutter-lifecycle` and `scope-guard`.
- The guard hooks in `.claude/hooks/` stop shortcuts, not attackers. `security` reports bypasses a session might plausibly type, not crafted obfuscation, because CI is the real gate.
- No push reminder hook: `docs-sync` and the coverage ratchet already enforce what it would check.
