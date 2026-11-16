# Build log: Medical Event Log

The rebuild is a test of how far the specs alone get (constitution III). From T003 on, each task adds its row here in its own commit, so the record is there to compare against `pre-rebuild` at the end.

- **Review rounds**: how many times `targeted-review` ran before every reviewer passed.
- **Reviewer FAILs**: each reviewer that failed, with its count of findings, for example `test-quality 2, clean-code 1`.
- **Clarify questions**: questions asked through `/speckit-clarify` or put to the user because the spec, plan or contracts had a gap or a conflict.
- **Stop rules**: the stop rules in `CLAUDE.md` (*Implementing a task*), or in an autonomous run those in `docs/dev-workflow/autonomous-runs.md`, that were hit, by number.
- **User stepped in**: the user corrected, redirected or decided something during the task, in a few words.
- **Decisions**: the `decisions.md` entries the task added in an autonomous run (`docs/dev-workflow/autonomous-runs.md`), for example `D-003, D-004`.

| Task | Review rounds | Reviewer FAILs | Clarify questions | Stop rules | User stepped in | Decisions |
|---|---|---|---|---|---|---|
| T001 | not recorded | not recorded | not recorded | — | not recorded | — |
| T002 | not recorded | not recorded | not recorded | — | not recorded | — |
| T003 | 2 | comment-hygiene 2, docs-sync 2, test-quality 1 | — | — | — | — |
| T004 | 2 | docs-sync 2 | 1 | 3 | chose to amend the constitution so features can merge per phase | — |
| T005 | 4 | clean-code 2, docs-sync 2, scope-guard 1, security 1, test-quality 1 | — | — | — | D-001 |
| T006 | 3 | clean-code 2, docs-sync 2 | — | — | — | D-001 (widened) |
| T007 | 2 | docs-sync 1 | — | 3 | — | D-002 |
| T008 | 2 | scope-guard 3 | — | — | — | D-001 (widened) |
| T009 | 2 | — | — | — | — | — |
| T010 | 1 | — | — | — | — | — |
| T011 | 2 | clean-code 1, test-quality 1 | — | 3 | — | D-003 |
| T012 | 1 | — | — | — | — | D-003 (widened) |
| T013 | 2 | clean-code 1, test-quality 1 | — | 3 | — | D-004 |
| T014 | 2 | test-quality 1 | — | — | — | — |
