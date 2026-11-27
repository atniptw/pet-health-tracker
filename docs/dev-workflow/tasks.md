# Tasks: Development workflow: reviewers and gates

**Spec**: [spec.md](spec.md) | **Plan**: [plan.md](plan.md)

One commit per task, each safe to ship on its own.

- [x] T001 Hook: block `--no-verify`
- [x] T002 Coverage ratchet
- [x] T003 Agent definitions
- [x] T004 Rewrite `targeted-review` to use the named agents
- [x] T005 Mechanical checks: size limits with a baseline, banned comment phrases, tests present
- [x] T006 Review gate and stamp hooks
- T007 Push reminder hook: dropped, see *Push reminder* under Hooks in [plan.md](plan.md).
- [x] T008 Workflow section in `CLAUDE.md`
- [x] T009 Harness review after each phase: the `harness-review` skill and constitution workflow step 6
- [x] T010 Reviewer Bash denials say what to send instead: one command per call, no `git -C`, `git grep -e` per alternative, the Grep or Read tool (harness review of 001 Phase 6)
- [x] T011 The commit gate's denial says when nothing chained with the commit ran, and `targeted-review` checks the fixes are staged before reviewers re-check them (harness review of 001 Phase 6)
- [x] T012 Reviewers search with `git grep` and `git ls-files`: the hook's denials and `review-protocol` stop sending them to a Grep or Glob tool Claude Code doesn't give them, and say to put `.` in a `git grep` pattern in place of a character the hook refuses (harness review of 001 Phase 7)
- [x] T013 `check.sh` checks each spec's Status line against its `tasks.md` (`scripts/spec-status.sh`): `Implemented` once every task is ticked, and not while one is open (harness review of 001 Phase 8)
- [x] T014 `CLAUDE.md` *Implementing a task* says to update a `decisions.md` entry's Changed and To undo lines when a task changes the code it names (harness review of 001 Phase 8)
- [x] T015 `review-protocol` tells reviewers not to report what they predict formatting, `flutter analyze` or the tests will say, since `check.sh` runs them, and release-safety's *Standalone commit* item leaves that to `check.sh` (harness review of 001 Phase 8)
- [x] T016 A SessionStart hook (`.claude/hooks/merged-branch.sh`) says when the checked-out branch's pull request has already merged, and how to get onto `main` (harness review of 001 Phase 9)
- [x] T017 `scripts/fails-without-fix.sh` runs the given tests against `HEAD`'s `lib/` in a temporary worktree, so a test can be seen failing without its fix without stashing, and `CLAUDE.md` step 2 points to it (harness review of 001 Phase 9)
