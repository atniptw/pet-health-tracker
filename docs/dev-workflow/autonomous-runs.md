# Autonomous runs

From 2026-11-15 to 2026-11-17, Phases 2 to 6 of spec 001 were built in autonomous runs: headless sessions that built each phase's tasks without asking the user. The user dropped them on 2026-11-21 because they used too much of the usage limit, and every session now follows the stop rules in `CLAUDE.md` (*Implementing a task*). What the runs left behind is each feature's `decisions.md`, the choices Claude made where it would otherwise have asked, waiting for the user's review (constitution III).

## `decisions.md`

`specs/<feature>/decisions.md` holds entries numbered `D-001` on in the order they were made. They are never renumbered or removed. An entry looks like this:

```markdown
## D-003 · Spec gap · T012: newest event first when two share a time

- **Question**: The spec sorts the list by time, but not events logged in the same minute.
- **Options**: (a) newest logged first; (b) oldest logged first; (c) by event type name.
- **Chose**: (a), since "most recent first" in US2 reads as the order they were logged.
- **Changed**: spec.md Clarifications; contracts/screens.md, Event list
- **To undo**: change the sort in `EventRepository.watchEvents` and its test.
- **Status**: open
```

The kinds are:

- **Spec gap**: the spec, plan or contracts didn't say.
- **Conflict**: two of them disagreed; the entry says which one was followed.
- **Choice**: a choice the user would see, or that would be costly to change, which the spec and plan left open.
- **New task**: a task added to `tasks.md` under stop rule 4.
- **Blocker**: what stopped a run, what was tried, and what the user needs to do.

A spec gap was also recorded in the spec's *Clarifications*, under `### Session <date> (autonomous run)`, as `- Q: <question> → A: <answer> (assumed, D-NNN)`.

Every entry starts as `open`. When reviewing, the user sets each one to `accepted`, or to `changed` with what they want instead, which then becomes a task. A blocker becomes `resolved` once the user has done what it asks.

## Reviewing the entries

Read the `open` entries in each `specs/*/decisions.md`, newest feature first, then the build log rows with more than 2 review rounds or a stop rule hit. A changed decision goes back through `/speckit-clarify`, which updates the spec and adds the task that changes the code.

## Build log rows from the runs

In the build log rows the runs wrote, the **Stop rules** column numbers the rules as `CLAUDE.md` does, but rules 1, 3 and 5 had these meanings in a run:

1. The same check failing after three different fixes was a blocker.
3. A gap or conflict in the spec, plan or contracts was settled by Claude and recorded in `decisions.md`.
5. A reviewer `FAIL` still standing after a second round of fixes, or after the reviewer was sent the spec sentence it conflicted with, was a blocker.

The **Decisions** column lists the `decisions.md` entries each task added.
