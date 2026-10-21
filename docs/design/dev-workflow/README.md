# Development workflow: reviewers and gates

## Overview
Every push to `main` ships to testers, so each commit has to pass checks that can't be skipped. Anything a script can measure goes in `scripts/check.sh`, so it applies to people, Claude and CI alike. Questions that need judgment go to narrow reviewer agents. Claude Code hooks decide which reviewers a commit needs, and block the commit until each of them passes.

## Reviewer agents
Each agent is defined in `.claude/agents/<name>.md`. It reviews the staged diff against a fixed checklist, and lists what it must not report because another agent owns it. All of them preload the `review-protocol` skill (`.claude/skills/review-protocol/`), which sets the report format: findings as `file:line`, what goes wrong, why and the fix, and a last line of `VERDICT: PASS` or `VERDICT: FAIL`. They are read-only: Read, Grep, Glob, and Bash limited to read-only git commands by `.claude/hooks/reviewer-bash.sh`.

Each agent's `Paths:` line lists the git pathspecs that make it required. That line is the source of truth; the table summarises it.

| Agent | Checks | Required when staged changes touch |
|---|---|---|
| `clean-code` | Large methods, files and `build()` methods; complex methods (nesting, branching); single responsibility; duplication with existing code in `lib/`; naming | `lib/` |
| `comment-hygiene` | Doc comments stay lean. Flags temporal comments ("now", "previously", "after the redesign", "new"), story-telling, comments that restate the code, and roadmap wording ("later", "v2", "for now") | Dart, rules, shell, JavaScript and workflow files, `.githooks/` |
| `docs-sync` | `CLAUDE.md` project state, `docs/architecture.md`, `docs/data-model.md` and design READMEs match the code and `firestore.rules`. Nothing described as planned has already shipped, and nothing described as shipped is missing | `lib/`, `firestore.rules`, `docs/`, `CLAUDE.md`, `scripts/`, `.github/`, `.claude/`, `.githooks/` |
| `security` | Rules: privilege escalation, field validation, membership checks. Personal or health data reaching logs or Crashlytics. Secrets. Auth edge cases | `firestore.rules`, `lib/data/`, `lib/core/`, `lib/features/auth/`, `android/`, `ios/`, `.github/`, `scripts/`, `firestore-tests/` scripts |
| `test-quality` | Every behavior change has a test that would fail without it. Tests check behavior, not implementation. Every new rule path has allow and deny tests. No assertions got weaker | `lib/`, `firestore.rules`, `test/`, `firestore-tests/`, `integration_test/`, `scripts/`, `.claude/hooks/`, `.githooks/` |
| `release-safety` | Rules changes don't break app versions testers still have. Schema changes handle existing documents that lack new fields. The commit is safe to ship on its own | `firestore.rules`, `lib/data/`, `lib/core/`, `pubspec.yaml`, `android/`, `ios/`, `.github/`, `assets/catalog/` |
| `flutter-lifecycle` | `setState` after dispose, double-submit, stream and provider lifecycle, stale data after switching account or household | `lib/features/`, `lib/core/` |
| `scope-guard` | Features, settings, options or wording that nobody asked for (the `CLAUDE.md` working rule) | `lib/`, `docs/`, `CLAUDE.md` |

The `targeted-review` skill launches the required agents in parallel and merges their output into one punch list.

## Mechanical checks (`scripts/check.sh`)
- **Size limits:** files up to 300 lines, functions and methods up to 40 lines. Files that are already over the limit are listed in a baseline file. An entry can only be removed, and each removal is its own refactor commit.
- **Banned comment phrases:** a grep with an allowlist for real uses.
- **Coverage ratchet:** `scripts/coverage.sh` fails if actual coverage is more than 0.2% above the minimum, so the minimum has to be raised.
- **Tests present:** if `lib/` changed but nothing under `test/` did, the check fails unless the commit is a `refactor:`.

## Hooks (`.claude/settings.json`)
1. **No skipping git hooks:** a PreToolUse hook on Bash (`.claude/hooks/block-no-verify.sh`) denies these, quoted or not:
   - `git commit` or `git push` with `--no-verify` or a prefix of it (`--no-veri`), including inside `bash -c`, outside a commit message
   - `git commit -n`, git aliases for `commit` or `push`, and `git send-pack`
   - setting `core.hooksPath` to anything but `.githooks`, or unsetting it
   - setting `COVERAGE_ROOT`, which would point the coverage check at other files
   - `git commit`, `git push` or a `COVERAGE_` variable in a command that also uses `$`, braces or backslashes outside a commit message, since expansion can build a flag after the hook has read the command

   It guards against taking a shortcut, not against a determined attacker. CI runs every check again, and every deploy job waits for it.
2. **Review gate on every commit:** a PreToolUse hook on `git commit` maps the staged paths to the required reviewers (table above). It denies the commit, naming the reviewers still missing, unless each one has a passing stamp for the current staged diff of its paths.
3. **Stamps:** a SubagentStop hook writes the stamps, so Claude doesn't. It reads `agent_type` and the final report (`last_assistant_message`, or `tool_input.message` on `SubagentHandback`). On `VERDICT: PASS` it writes a stamp holding the hash of `git diff --cached` for that agent's paths. If the staged diff changes, the stamp no longer matches and that reviewer has to run again.
4. **Push reminder:** a PreToolUse hook on `git push` reminds Claude to confirm that the docs are updated and the coverage minimum was raised.

## Build order
One commit per step, each safe to ship on its own.
1. Hook: block `--no-verify` (done)
2. Coverage ratchet (done)
3. Agent definitions (done)
4. Rewrite `targeted-review` to use the named agents
5. Mechanical checks: size limits with a baseline, banned comment phrases, tests present
6. Review gate and stamp hooks
7. Push reminder hook
8. Workflow section in `CLAUDE.md`

## Decisions
- Review runs on every commit, not every push.
- All reviewers block: a `FAIL` verdict stops the commit until it's fixed.
- Limits: 300 lines per file, 40 per function. Current offenders go in a baseline and get refactored in separate commits.
- All eight reviewers above are in, including `test-quality`, `release-safety`, `flutter-lifecycle` and `scope-guard`.
- The guard hooks in `.claude/hooks/` stop shortcuts, not attackers. `security` reports bypasses a session might plausibly type, not crafted obfuscation, because CI is the real gate.
