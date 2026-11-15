# Autonomous runs

In an autonomous run Claude plans and builds the specs in `specs/` without asking the user. Every choice it would otherwise have asked about goes into the feature's `decisions.md` for the user to review after the run (constitution, *Autonomous runs*). The task loop, checks, reviewer gates and commit gate are the same as in any other session (`CLAUDE.md`, *Implementing a task*). Only the stop rules change.

A session is in an autonomous run when its prompt starts with `Autonomous run`. The prompt names one step:

- **Plan `<spec dir>`**: the feature has a spec but no `tasks.md`.
- **Phase `<n>` of `<spec dir>`**: build every unticked task in that phase of the feature's `tasks.md`.

## Starting a run

`scripts/autopilot.sh` runs the steps one after another, each in a fresh headless session (`claude -p`), until every spec in `specs/` is built. Before each step it switches its checkout to `origin/main` and picks the first spec, in number order, that has no `tasks.md` (a plan step) or has an unticked task (a phase step, for the first phase with one). It needs a clean tree, so give it a worktree of its own:

```
git worktree add --detach ../pet-health-tracker-autopilot origin/main
cd ../pet-health-tracker-autopilot
flutter pub get
./scripts/autopilot.sh
```

`./scripts/autopilot.sh --next` prints the step it would start, and starts nothing. Each session runs with `--permission-mode auto --permission-prompts none`, so anything that would ask for permission is denied rather than waiting for the user. It also gets `SPECIFY_FEATURE_DIRECTORY` set to its spec, so the `/speckit-*` skills work on that feature. Each session's output goes to `$(git rev-parse --git-common-dir)/autopilot/<time>-<step>.log`.

A session that ends on a usage limit is resumed (`claude -p --resume`, same session) once the limit resets: a minute after the reset time when the message gives one, otherwise after half an hour, again and again until the step goes on. The wait is printed, and the run needs nothing from the user while it waits.

The run stops, and prints how many `decisions.md` entries are open in each feature, when:

- every task in every spec is ticked
- a `decisions.md` on `main` has an open `Blocker` entry
- a step leaves `origin/main` where it was, which means the session ended without merging anything; its log says why
- the tree has changes when a step would start
- a session that stopped on a usage limit left `.claude/` or `.githooks/` different from `origin/main`, since a resumed session would load those hooks and settings unreviewed

After resolving what stopped it, run it again: it carries on from the next step.

## Keeping a session's context small

A session builds a whole phase, so it hands the noisy work to subagents and keeps only their summaries:

- **Each task** is built by a `general-purpose` subagent, given the task id, the spec dir and *Implementing a task* steps 1 to 3 with the stop rules below. It writes the tests and code, runs `./scripts/test.sh` and `./scripts/check.sh`, and hands back the files it changed, the covered ids, the check result and any `decisions.md` entries it made, in a few lines. It does not stage or commit.
- **The session** stages the task, runs `targeted-review` (the reviewers are subagents too), sends findings back to the task's subagent with `SendMessage` to fix, and commits once every reviewer passes, since the commit gate and review stamps belong to it.
- **Broad searches and long logs**, such as a failing CI run, go to an `Explore` or `general-purpose` subagent that hands back only what was found.

A subagent that stopped on a usage limit hasn't failed: once usage resets, continue it with `SendMessage`.

## A plan step

1. Create the branch `<feature>-plan` from `origin/main`, for example `002-shared-households-plan`.
2. Run `/speckit-plan`, `/speckit-tasks` and `/speckit-analyze` for the feature. Answer their questions as *Settling a gap* says, and fix what `/speckit-analyze` finds.
3. Stage the plan, its design docs and `tasks.md`, review them with `targeted-review`, and commit them as one `docs: plan <feature name> (spec NNN)` commit.
4. Merge as *Merging* says.

## A phase step

1. Create the branch `<feature>-p<n>` from `origin/main`, for example `001-medical-event-log-p2`.
2. Build each unticked task in phase `<n>`, in order, one commit each, with the loop in `CLAUDE.md` (*Implementing a task*) and the stop rules below.
3. Merge as *Merging* says, including when a blocker ended the phase early, so the finished tasks are on `main`.

## Merging

Push the branch, open a pull request with `gh pr create` whose body lists the tasks it holds and the `decisions.md` entries they added, and merge it with `gh pr merge --rebase --delete-branch`. Then find the CI run for the new tip of `main` (`gh run list --branch main --commit <sha> --json databaseId`) and wait for it with `gh run watch <id> --exit-status`. A failed run is a blocker.

## Stop rules in a run

Rules 1, 3 and 5 in `CLAUDE.md` read like this in a run. Rules 2, 4 and 6 stay as they are: a test that looks wrong (rule 2) is a blocker, a task added under rule 4 also gets a `New task` entry in `decisions.md`, and each step is a fresh session (rule 6). The build log's **Stop rules** column uses these same numbers.

1. **The same check failing after three different fixes** is a blocker. Write down what was tried, save the unfinished task's changes as a patch in `$(git rev-parse --git-common-dir)/autopilot/<task>.patch` (`git add -A`, then `git diff --cached --binary` into that file), reset the tree to the last commit with `git reset --hard`, and merge the tasks already done.
3. **A gap or conflict in the spec, plan or contracts** is settled by Claude, as *Settling a gap* says, and the run goes on.
5. **A reviewer `FAIL` that still stands after one round of fixes**: fix it a second time. If the finding conflicts with the spec, send the reviewer the spec sentence once with `SendMessage`. A `FAIL` that still stands after that is a blocker.

Each of these is a blocker too, never worked around:

- anything that needs the user's accounts, consoles, secrets, devices or money: the Firebase, Google Cloud, Play and App Store Connect consoles, repository variables and secrets
- turning deploys on, which ends the rebuild period (constitution III)
- changing the constitution, `.claude/` (hooks, agents, skills, settings), `.githooks/`, or the checks `scripts/check.sh` runs; raising the coverage minimum and lowering size baseline entries are the only changes to those allowed
- force-pushing, pushing to `main` directly, or deleting any branch but a pull request's own branch as it merges
- reading the `pre-rebuild` tag or earlier history for how to build anything (constitution III)

A blocker entry is committed on its own as `docs: record blocker D-NNN (<task>)`, reviewed like any commit, and merged with the phase, so the next session and the user see it on `main`.

## Settling a gap

1. List the options the spec, plan and contracts leave open.
2. Pick the one the spec's own wording points to, then the one the contracts or plan already imply. Failing both, pick the one that adds the least for the user (constitution II) and is the easiest to change after review.
3. Record it in `decisions.md`. For a gap in the spec, also add `- Q: <question> → A: <answer> (assumed, D-NNN)` under `### Session <date> (autonomous run)` in the spec's *Clarifications*. Fix the plan or contracts when they are the part in conflict.
4. Write the tests from the decision, like any other spec sentence.

## `decisions.md`

Each feature has `specs/<feature>/decisions.md`, created with its first entry. Entries are numbered `D-001` on in the order they are made, and are never renumbered or removed. An entry looks like this:

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

- **Spec gap**: the spec, plan or contracts don't say.
- **Conflict**: two of them disagree; say which one was followed.
- **Choice**: a choice the user would see, or that would be costly to change, which the spec and plan leave open. Ordinary code choices aren't logged.
- **New task**: a task added to `tasks.md` under stop rule 4.
- **Blocker**: what stopped the run, what was tried, and what the user needs to do. It names the patch file when there is one.

Every entry starts as `open`. When reviewing, the user sets each one to `accepted`, or to `changed` with what they want instead, which then becomes a task. A blocker becomes `resolved` once the user has done what it asks.

The build log row for each task lists the entries it added, in its **Decisions** column.

## Reviewing a run

Read the `open` entries in each `specs/*/decisions.md`, newest feature first, then the build log rows with review rounds above 2 or a stop rule hit. A changed decision goes back through `/speckit-clarify`, which updates the spec and adds the task that changes the code.
