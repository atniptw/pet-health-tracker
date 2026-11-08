<!--
Sync Impact Report
- Version: 2.0.0 → 2.1.0 (MINOR: workflow step added)
- Modified principles: none
- Added sections: Workflow step 6, Review the harness. After each feature merges, the
  harness-review skill builds the clear-cut harness improvements and proposes the rest.
- Removed sections: none
- Dependent files to update: CLAUDE.md (summary of the rules), specs/002-dev-workflow/plan.md
  (describes the skills)
- Deferred placeholders: none
-->

# Pet Health Tracker Constitution

## Core Principles

### I. Fast symptom logging
The app is for pet owners in general, on iOS and Android, to track their pets' health symptoms. Fast symptom logging comes first: capturing what happened and when, with as little friction as possible.

### II. Only what was asked
Specs, plans, tasks, code, comments and replies hold only what the user asked for and the choices the user made. Nothing is labelled "out of scope for v1", "planned for later", "v2" or similar unless the user said so, and no features, phases or future work get added that the user didn't ask for. The phases in a plan and in `tasks.md` are the build order of the feature being specified, not deferred scope.

### III. Every commit ships
Every push to `main` ships to testers on Google Play internal testing and TestFlight. Each commit is one small, complete change that builds, passes its checks and makes sense on its own, with no half-wired feature visible to testers.

Only production releases have to stay compatible with older app versions. A production release is a build released to the public on the App Store or on Google Play's production track. Testers are told that features may break and that the app or its data may need resetting, so a change does not have to keep older test builds or existing test data working. Once a production release exists, rules and data changes stay compatible with every production version users may still run, and data changes handle documents that lack new fields. Test and production builds share the same rules and data, so from then on this applies to every push to `main`.

### IV. Tests with every behavior change
Every behavior change comes with tests: unit and widget tests in `test/`, security rules tests in `firestore-tests/`, and allow and deny tests for every new rule path. The failing test comes first when practical. Only a `refactor:` commit changes `lib/` (other than the generated `lib/firebase_options.dart`) without changing `test/` or `integration_test/`.

### V. Checks are never bypassed
`./scripts/check.sh` passes before every commit and every push. Nothing skips the git hooks (`--no-verify`) or the commit gate. The coverage minimum in `scripts/coverage.sh` only goes up: it is raised when coverage is more than 0.2% above it, and never lowered to get a change through. The size limits in `tool/size_check.dart` hold, and entries in `tool/size_baseline.txt` are only lowered or removed.

## Workflow

1. **Specify.** `/speckit-specify` creates the feature branch (`NNN-short-name`, from the git extension) and `specs/NNN-short-name/spec.md`, with the user's decisions recorded as they make them.
2. **Plan and tasks.** `/speckit-plan` writes `plan.md` and `/speckit-tasks` writes `tasks.md`. Each task in `tasks.md` is one commit and is safe to ship on its own.
3. **Implement one task per commit.** For each task: write the failing test, make the change, run `./scripts/check.sh`, stage exactly that task, review it with the `targeted-review` skill, then `git commit -q -m "<type>: <subject>"` and tick the task in `tasks.md` in the same commit. `/speckit-implement` works through the tasks the same way. The git extension's auto-commit stays off.
4. **Merge.** Push the branch and open a pull request with `gh`. It is merged to `main` with a rebase merge, so every reviewed commit lands on `main` as it is. A feature can merge after each task or once at the end.
5. **Keep docs true.** When a task ships or a decision changes, the spec, plan and tasks, `CLAUDE.md`, `docs/architecture.md` and `docs/data-model.md` are updated in the same commit.
6. **Review the harness.** After a feature merges, the `harness-review` skill looks back over it for friction in the Claude Code harness: agents, skills, scripts, hooks, settings, plugins, MCP servers and CI. It builds the clear-cut improvements, each one small commit that doesn't relax a check, a gate or a permission, add a blocking reviewer or hook, a plugin, an MCP server or a dependency, or amend the constitution. It proposes the rest to the user, who decides which to build. Each improvement is committed and merged as in steps 3 and 4: `./scripts/check.sh`, the `targeted-review` skill, one commit each, and a pull request.

## Review gates

The reviewer agents in `.claude/agents/` each own one concern. `./scripts/required-reviewers.sh` names the ones a staged change needs, from each agent's `Paths:` line, and all of them block: a `FAIL` stops the commit until it is fixed. The commit gate (`.claude/hooks/review-gate.sh`) denies `git commit` until every required reviewer has passed the current staged diff. Nothing is staged while reviewers run. CI runs `check.sh`, `scripts/tests-changed.sh` and the integration tests again on every push to `main` before anything deploys.

## Governance

This constitution takes precedence over other workflow guidance in the repository. `CLAUDE.md` holds the commands, project state and CI details, and points here for the rules. An amendment is its own reviewed commit that records the user's decision, bumps the version (major for a removed or redefined principle, minor for an added principle or section, patch for wording) and updates `CLAUDE.md` where it depends on the change. The `Constitution Check` in each plan `/speckit-plan` writes checks it against these principles.

**Version**: 2.1.0 | **Ratified**: 2026-11-07 | **Last Amended**: 2026-11-08
