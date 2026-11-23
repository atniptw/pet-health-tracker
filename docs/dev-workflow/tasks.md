# Tasks: Development workflow: reviewers and gates

**Spec**: [spec.md](spec.md) | **Plan**: [plan.md](plan.md)

One commit per task, each safe to ship on its own.

- [x] T001 Hook: block `--no-verify`
- [x] T002 Coverage ratchet
- [x] T003 Agent definitions
- [x] T004 Rewrite `targeted-review` to use the named agents
- [x] T005 Mechanical checks: size limits with a baseline, banned comment phrases, tests present
- [x] T006 Review gate and stamp hooks
- T007 Push reminder hook: dropped, see hook 4 in [plan.md](plan.md).
- [x] T008 Workflow section in `CLAUDE.md`
- [x] T009 Harness review after each phase: the `harness-review` skill and constitution workflow step 6
- [x] T010 Reviewer Bash denials say what to send instead: one command per call, no `git -C`, `git grep -e` per alternative, the Grep or Read tool (harness review of 001 Phase 6)
- [x] T011 The commit gate's denial says when nothing chained with the commit ran, and `targeted-review` checks the fixes are staged before reviewers re-check them (harness review of 001 Phase 6)
