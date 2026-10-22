# Development workflow: reviewers and gates

## Overview
Every push to `main` ships to testers, so each commit has to pass checks that can't be skipped. Anything a script can measure goes in `scripts/check.sh`, so it applies to people, Claude and CI alike. Questions that need judgment go to narrow reviewer agents. Claude Code hooks decide which reviewers a commit needs, and block the commit until each of them passes.

## Reviewer agents
Each agent is defined in `.claude/agents/<name>.md`. It reviews the staged diff against a fixed checklist, and lists what it must not report because another agent owns it. All of them preload the `review-protocol` skill (`.claude/skills/review-protocol/`), which sets the report format: findings as `file:line`, what goes wrong, why and the fix, and a last line of `VERDICT: PASS` or `VERDICT: FAIL`. They are read-only: Read, Grep, Glob, and Bash limited to read-only git commands by `.claude/hooks/reviewer-bash.sh`.

Each agent's `Paths:` line lists the git pathspecs that make it required. That line is the source of truth; the table summarises it. `scripts/required-reviewers.sh` reads those lines and prints the reviewers a diff needs: the staged change by default, or a commit range. It reads the agents from git, from both the last commit and the staged copy with their names and paths combined, so an edit to an agent file can't narrow which reviewers run. An agent without a `Paths:` line is an error.

| Agent | Checks | Required when staged changes touch |
|---|---|---|
| `clean-code` | Large methods, files and `build()` methods; complex methods (nesting, branching); single responsibility; duplication with existing code in `lib/`; naming | `lib/`, `tool/` |
| `comment-hygiene` | Doc comments stay lean. Flags temporal comments ("now", "previously", "after the redesign", "new"), story-telling, comments that restate the code, and roadmap wording ("later", "v2", "for now") | Dart, rules, shell, JavaScript and workflow files, `.githooks/`, `scripts/comment-allowlist.txt` |
| `docs-sync` | `CLAUDE.md` project state, `docs/architecture.md`, `docs/data-model.md` and design READMEs match the code and `firestore.rules`. Nothing described as planned has already shipped, and nothing described as shipped is missing | `lib/`, `firestore.rules`, `docs/`, `CLAUDE.md`, `scripts/`, `.github/`, `.claude/`, `.githooks/`, `tool/` |
| `security` | Rules: privilege escalation, field validation, membership checks. Personal or health data reaching logs or Crashlytics. Secrets. Auth edge cases | `firestore.rules`, `lib/data/`, `lib/core/`, `lib/features/auth/`, `android/`, `ios/`, `.github/`, `scripts/`, `firestore-tests/` scripts, `.claude/hooks/`, `.claude/settings.json` |
| `test-quality` | Every behavior change has a test that would fail without it. Tests check behavior, not implementation. Every new rule path has allow and deny tests. No assertions got weaker | `lib/`, `firestore.rules`, `test/`, `firestore-tests/`, `integration_test/`, `scripts/`, `.claude/hooks/`, `.githooks/`, `tool/` |
| `release-safety` | Rules changes don't break app versions testers still have. Schema changes handle existing documents that lack new fields. The commit is safe to ship on its own | `firestore.rules`, `lib/data/`, `lib/core/`, `pubspec.yaml`, `android/`, `ios/`, `.github/`, `assets/catalog/` |
| `flutter-lifecycle` | `setState` after dispose, double-submit, stream and provider lifecycle, stale data after switching account or household | `lib/features/`, `lib/core/` |
| `scope-guard` | Features, settings, options or wording that nobody asked for (the `CLAUDE.md` working rule) | `lib/`, `docs/`, `CLAUDE.md` |

The `targeted-review` skill runs `scripts/required-reviewers.sh`, launches exactly those agents in parallel, and merges their output into one punch list. After fixes, every required reviewer whose paths the fixes touched has to pass again. The skill continues the reviewer's existing agent with `SendMessage` rather than starting a new one.

## Mechanical checks (`scripts/check.sh`)
- **Size limits:** files in `lib/` up to 300 lines, and functions, methods and constructors up to 40, measured with the Dart analyzer by `tool/size_check.dart`. Files and functions already over a limit are listed in `tool/size_baseline.txt` at their exact size. The check fails when an entry grows, when it shrinks and the baseline isn't lowered to match, and when it no longer exists. Entries can only be lowered or removed, and each removal is its own refactor commit. `clean-code` reviews every change to `tool/`, so an added or raised baseline entry, a raised limit or a newly excluded file is a finding.
- **Banned comment phrases:** `scripts/comment-check.sh` fails when a comment in a tracked Dart, shell, rules, JavaScript or workflow file says "for now", "for the time being", "previously", "anymore", "eventually", "in the future", "later on", "TODO later", a version like "v2" or a phase like "phase 2". Words like "new", "old" and "no longer" have timeless uses in this code, so `comment-hygiene` judges those. `scripts/comment-allowlist.txt` allows a phrase in one file, and `comment-hygiene` reviews every entry.
- **Coverage ratchet:** `scripts/coverage.sh` fails if actual coverage is more than 0.2% above the minimum, so the minimum has to be raised.
- **Tests present:** `scripts/tests-changed.sh` fails on a commit that changes `lib/` (other than the generated `lib/firebase_options.dart`) without changing `test/` or `integration_test/`, unless its subject is a `refactor:` (with or without a scope). `check.sh` checks the commits not yet on `origin/main`. In CI that range is empty, so the test job runs the script on the pushed commits and checks out full history for it. After a force-push it fetches the old tip by id, and fails if it can't rather than skip commits.

## Hooks (`.claude/settings.json`)
1. **No skipping git hooks:** a PreToolUse hook on Bash (`.claude/hooks/block-no-verify.sh`) denies these, quoted or not:
   - `git commit` or `git push` with `--no-verify` or a prefix of it (`--no-veri`), including inside `bash -c`, outside a commit message
   - `git commit -n`, git aliases for `commit` or `push`, and `git send-pack`
   - setting `core.hooksPath` to anything but `.githooks`, or unsetting it
   - setting `COVERAGE_ROOT`, which would point the coverage check at other files
   - `git commit`, `git push` or a `COVERAGE_` variable in a command that also uses `$`, braces or backslashes outside a commit message, since expansion can build a flag after the hook has read the command

   It guards against taking a shortcut, not against a determined attacker. CI runs every check again, and every deploy job waits for it.
2. **Review gate on every commit:** `.claude/hooks/review-gate.sh`, a PreToolUse hook on Bash, runs `scripts/required-reviewers.sh` when a command runs `git commit`. It denies the commit, naming the reviewers still missing, unless each one has a stamp matching the hash of the current staged diff of its paths (`scripts/required-reviewers.sh --hashes`). Because it checks only the staged change, a commit may use only `-m`, `-q`, `-s`, `-v`, `--amend`, `--no-edit`, `--allow-empty` and `--dry-run`. `-a`, pathspecs, `-F` and the rest are denied, and so is a commit whose `-C` or `cd` target is another worktree. It reads each command twice, both times with commit messages dropped (`.claude/hooks/command-text.sh`, shared with `block-no-verify.sh`). One reading removes the quotes, which finds commits inside `bash -c` or after a prefix like `env`. The other keeps each quoted argument whole, which finds a commit after an option value with a space in it, like `-c user.name="A B"`. A commit in either reading counts. It denies the commit if it fails in any way, including when `jq` can't read the command or the reviewer mapping fails.
3. **Stamps:** `.claude/hooks/review-stamp.sh` writes them, so Claude doesn't. On SubagentStart it records the reviewer's hash for that run. On PostToolUse of `SubagentHandback` it keeps the report. On SubagentStop it writes the stamp, holding the hash from the start of the run, if the report's last line is `VERDICT: PASS`, and removes the reviewer's stamp otherwise. If no report was handed back, it reads `last_assistant_message`. Anything staged after a run started therefore needs another run. A change staged and then unstaged during a run goes unnoticed. Stamps live in the git directory (`review-stamps/`), so they are never committed and belong to one clone.
4. **Push reminder:** a PreToolUse hook on `git push` reminds Claude to confirm that the docs are updated and the coverage minimum was raised.

## Build order
One commit per step, each safe to ship on its own.
1. Hook: block `--no-verify` (done)
2. Coverage ratchet (done)
3. Agent definitions (done)
4. Rewrite `targeted-review` to use the named agents (done)
5. Mechanical checks: size limits with a baseline, banned comment phrases, tests present (done)
6. Review gate and stamp hooks (done)
7. Push reminder hook
8. Workflow section in `CLAUDE.md`

## Decisions
- Review runs on every commit, not every push.
- All reviewers block: a `FAIL` verdict stops the commit until it's fixed.
- Limits: 300 lines per file, 40 per function. Current offenders go in a baseline and get refactored in separate commits.
- All eight reviewers above are in, including `test-quality`, `release-safety`, `flutter-lifecycle` and `scope-guard`.
- The guard hooks in `.claude/hooks/` stop shortcuts, not attackers. `security` reports bypasses a session might plausibly type, not crafted obfuscation, because CI is the real gate.
