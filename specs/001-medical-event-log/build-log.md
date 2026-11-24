# Build log: Medical Event Log

The rebuild is a test of how far the specs alone get (constitution III). From T003 on, each task adds its row here in its own commit, so the record is there to compare against `pre-rebuild` at the end.

- **Review rounds**: how many times `targeted-review` ran before every reviewer passed.
- **Reviewer FAILs**: each reviewer that failed, with its count of findings, for example `test-quality 2, clean-code 1`.
- **Clarify questions**: questions asked through `/speckit-clarify` or put to the user because the spec, plan or contracts had a gap or a conflict.
- **Stop rules**: the stop rules in `CLAUDE.md` (*Implementing a task*) that were hit, by number. In the rows the autonomous runs wrote (T005 to T032), rules 1, 3 and 5 have the meanings in `docs/dev-workflow/autonomous-runs.md`.
- **User stepped in**: the user corrected, redirected or decided something during the task, in a few words.
- **Decisions**: the `decisions.md` entries the task added in the autonomous runs (`docs/dev-workflow/autonomous-runs.md`), for example `D-003, D-004`.

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
| T015 | 4 | comment-hygiene 1, docs-sync 1, flutter-lifecycle 1, security 1 | — | 3 | — | D-005 |
| T016 | 2 | docs-sync 1, test-quality 1 | — | 3 | — | D-006 |
| T017 | 2 | clean-code 1, comment-hygiene 1, docs-sync 1, test-quality 1 | — | 3 | — | D-007 |
| T018 | 1 | — | — | 3 | — | D-008 |
| T019 | 2 | scope-guard 2 | — | — | — | — |
| T020 | 2 | comment-hygiene 1, docs-sync 2 | — | — | — | D-009 |
| T021 | 2 | clean-code 1 | — | 3 | — | D-010, D-011, D-012 |
| T022 | 3 | comment-hygiene 1, flutter-lifecycle 1, test-quality 1 | — | — | — | D-013 |
| T023 | 2 | docs-sync 1, flutter-lifecycle 1 | — | 3 | — | D-014, D-015, D-016 |
| T024 | 2 | docs-sync 2, flutter-lifecycle 1 | — | — | — | D-017 |
| T025 | 2 | clean-code 1 | — | — | — | D-018 |
| T026 | 2 | test-quality 1 | — | 3 | — | D-021 |
| T027 | 2 | docs-sync 1 | — | 3 | — | D-022 |
| T028 | 2 | test-quality 1 | — | 3 | — | D-023 |
| T029 | 2 | clean-code 2, comment-hygiene 1, test-quality 2 | — | 3 | — | D-024 |
| T030 | 2 | clean-code 1, test-quality 1 | — | 3, 4 | — | D-025, D-026, D-027 |
| T031 | 1 | — | — | 3 | — | D-028 |
| T032 | 2 | clean-code 1, comment-hygiene 1, docs-sync 1, test-quality 1 | — | 3 | — | D-029, D-030 |
| T033 | 3 | test-quality 3 | 5 | 3 | answered 4 questions on the Event screen (type dropdown, Save returns to the history, full screen "Event", Delete in the app bar), and kept an archived pet's own events editable (FR-015 reworded) | — |
| T034 | 2 | docs-sync 1, flutter-lifecycle 1, test-quality 1 | — | — | — | — |
| T039 | 2 | docs-sync 1 | — | — | asked for the flaky smoke test to be added as a task and fixed | — |
| T036 | 2 | clean-code 1, docs-sync 1, test-quality 1 | — | — | — | — |
| T037 | 3 | clean-code 1, comment-hygiene 1, docs-sync 2, release-safety 1, test-quality 1 | — | — | — | — |
| T038 | 2 | docs-sync 1 | — | — | — | — |
| T035 | 2 | docs-sync 1 | — | — | — | — |
