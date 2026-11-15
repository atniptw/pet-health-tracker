# Build log: Medical Event Log

The rebuild is a test of how far the specs alone get (constitution III). From T003 on, each task adds its row here in its own commit, so the record is there to compare against `pre-rebuild` at the end.

- **Review rounds**: how many times `targeted-review` ran before every reviewer passed.
- **Reviewer FAILs**: each reviewer that failed, with its count of findings, for example `test-quality 2, clean-code 1`.
- **Clarify questions**: questions asked through `/speckit-clarify` or put to the user because the spec, plan or contracts had a gap or a conflict.
- **Stop rules**: the stop rules in `CLAUDE.md` (*Implementing a task*) that were hit, by number.
- **User stepped in**: the user corrected, redirected or decided something during the task, in a few words.

| Task | Review rounds | Reviewer FAILs | Clarify questions | Stop rules | User stepped in |
|---|---|---|---|---|---|
| T001 | not recorded | not recorded | not recorded | — | not recorded |
| T002 | not recorded | not recorded | not recorded | — | not recorded |
| T003 | 2 | comment-hygiene 2, docs-sync 2, test-quality 1 | — | — | — |
