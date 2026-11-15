# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Goal

A mobile app (iOS + Android) for pet owners to record their pets' medical events so they can tell a vet what happened, when and how often. It is a medical record, not a diary or a social feed. The first priority is **fast logging**: capturing what happened and when, with as little friction as possible. The audience is pet owners in general, not just a single household.

## Rules and workflow

The project is a [Spec Kit](https://github.com/github/spec-kit) project. Its rules and workflow are in the constitution, `.specify/memory/constitution.md`: only what was asked, every commit ships (backward compatible only once there is a production release; testers may need to reset the app or its data; during the rebuild period deploys are off and the app is built from the specs alone), tests with every behavior change, checks are never bypassed, and one reviewed commit per task on a feature branch, rebase-merged to `main` through a pull request. The `/speckit-*` skills write each feature's `spec.md`, `plan.md` and `tasks.md` under `specs/`.

Each commit is staged exactly, reviewed with the `targeted-review` skill, and made with `git commit -q -m "<type>: <subject>"`. The commit gate (`.claude/hooks/review-gate.sh`) denies it until every reviewer `./scripts/required-reviewers.sh` names has passed the staged diff, and allows only `-m`, `-q`, `-s`, `-v`, `--amend`, `--no-edit`, `--allow-empty` and `--dry-run`. `git commit --dry-run -q -m x` names the reviewers still missing. Don't stage while reviewers run. The pre-push hook runs `check.sh` on every push, and CI runs it again with `scripts/tests-changed.sh` and the integration tests on every push to `main` before anything deploys. `docs/dev-workflow/plan.md` has the details.

## Implementing a task

Each task in a feature's `tasks.md` is one commit. For a task in `specs/<feature>/`:

1. **Read** the task, and the spec sentences behind each id on its **Covers** line.
2. **Test first**: write the tests, putting each covered id in a test's name, for example `testWidgets('001-US1-S3: several pets, none logged for → no pet picked', …)`. Use the wording in the feature's `contracts/screens.md` and the helpers in `test/support/`. Run `./scripts/test.sh <test files>` and see each new test fail for the reason the spec gives.
3. **Build** until `./scripts/test.sh <test files>` passes, then run `./scripts/check.sh`.
4. **Done** when `./scripts/spec-coverage.sh specs/<feature>` lists each id on the task's Covers line as covered, `check.sh` passes, and the `targeted-review` skill passes on the staged task. Tick the task in `tasks.md` and add its row to the feature's `build-log.md` before staging, since the commit gate accepts only the diff that was reviewed. Then commit with `git commit -q -m "<type>: <subject>"`.
5. **Merge** after the last task of each phase: push the branch and open a pull request with `gh`, and rebase-merge it to `main`, where CI runs `check.sh` and the integration tests.

Stop rules:

1. The same check failing after three different fixes: stop and tell the user what was tried, rather than trying a fourth.
2. Never change a test's expectation, skip a test or loosen a check to get a task through. If a test looks wrong, quote the spec sentence that shows it, or ask.
3. A spec gap or a conflict between spec, plan and contracts: stop and ask (`/speckit-clarify`), rather than guessing.
4. Change only the files the task needs. Something else that's broken becomes a new task in `tasks.md`, not part of this one.
5. A reviewer `FAIL` that still stands after one round of fixes, or that conflicts with the spec: ask the user.
6. Start a fresh session for each phase in `tasks.md`; the ticked tasks carry the state.

In an autonomous run (a session whose prompt starts with `Autonomous run`), `docs/dev-workflow/autonomous-runs.md` replaces stop rules 1, 3 and 5: Claude settles spec gaps itself, records every such choice and every blocker in the feature's `decisions.md` for the user to review after the run, and ends the run on a blocker.

## Project state

Flutter app (package `pet_health_tracker`, org `com.pootzandboogie` (Pootz&Boogie, the author's hobby-project label), iOS + Android only), in its rebuild period (constitution, principle III). The app is a single screen saying it is being rebuilt (`lib/app.dart`), and the Firestore rules deny every read and write. The app before the rebuild is tagged `pre-rebuild`. Crashlytics reports crashes from release builds.

## CI

`.github/workflows/release.yml` runs `scripts/check.sh` and the integration tests on an Android emulator on every push to `main`, then deploys Firestore rules and uploads to the Play internal testing track (fastlane, `android/fastlane/`). Deploy jobs are gated by repo variables (`FIRESTORE_RULES_DEPLOY_ENABLED`, `ANDROID_DEPLOY_ENABLED`, `IOS_DEPLOY_ENABLED`). Android deploys roll out straight to internal testers and iOS deploys upload to TestFlight (`ios/fastlane/`). All three variables are `false` for the rebuild period, so pushes to `main` run the checks and integration tests but deploy nothing. There is no production release yet: builds go only to Play internal testing and TestFlight. Setup steps and secrets are in `docs/ci.md`.

## Specs and design docs

The rebuild is specified in `specs/001-medical-event-log`, `specs/002-shared-households` and `specs/003-vet-view`. 001 has its plan, data model and tasks; 002 and 003 are specs only. None of it is implemented yet. Each feature's plan, data model and tasks go in its `specs/NNN-name/` directory, with its tasks showing which are done. The Firebase project, its cost limits and the sign-in providers' setup are in `docs/firebase-setup.md`. Reviewer agents (`.claude/agents/`) and the commit gates are described in `docs/dev-workflow/plan.md`, and autonomous runs, with each feature's `decisions.md`, in `docs/dev-workflow/autonomous-runs.md`. Keep them updated when decisions change or a planned piece ships.

## Commands

```
git config core.hooksPath .githooks      # once per clone: run checks before every push
flutter pub get                          # install dependencies
flutter run                              # run on a connected device/emulator
./scripts/check.sh                       # everything CI checks: format, analyze, tests (through scripts/test.sh), spec coverage, size limits, comment phrases, tests changed with lib/, coverage, hook tests, reviewer-mapping tests, review-gate tests, autopilot tests, rules tests
./scripts/test.sh                        # run all tests in test/, in the America/Chicago time zone, printing only failures; use it instead of flutter test for test/
./scripts/test.sh test/app_test.dart     # run a single test file
./scripts/test.sh --plain-name "<test name>"  # run a single test by name
./scripts/test-test-sh.sh                # tests for scripts/test.sh
./scripts/spec-coverage.sh [--strict] <spec dir>…  # spec ids (NNN-US<n>-S<m>, NNN-FR-NNN, NNN-EC-NN, NNN-SC-NNN) that no test name or untested.md line covers; fails on unknown ids, and with --strict on missing ones
./scripts/test-spec-coverage.sh          # tests for scripts/spec-coverage.sh
npm --prefix firestore-tests test        # security rules tests (starts the Firestore emulator on 8180)
dart tool/size_check.dart                # size limits for lib/ (300 lines a file, 40 a function) against tool/size_baseline.txt
./scripts/comment-check.sh               # comments with wording like "for now" or "v2" (allowed uses in scripts/comment-allowlist.txt)
./scripts/test-comment-check.sh          # tests for scripts/comment-check.sh
./scripts/tests-changed.sh [<from> <to>]  # commits that change lib/ without tests, unless a refactor (default: not yet on origin/main)
./scripts/test-tests-changed.sh          # tests for scripts/tests-changed.sh
./scripts/test-hooks.sh                  # tests for the Claude Code hooks in .claude/hooks
./scripts/test-coverage.sh               # tests for the coverage minimum and ratchet in scripts/coverage.sh
./scripts/required-reviewers.sh [<from> <to>]  # reviewer agents a diff needs (default: the staged change); --hashes for the commit gate
./scripts/test-required-reviewers.sh     # tests for scripts/required-reviewers.sh
./scripts/test-review-gate.sh            # tests for the review stamp and commit gate hooks in .claude/hooks
./scripts/autopilot.sh [--next]          # autonomous run: one fresh session per plan or phase step until every spec is built (docs/dev-workflow/autonomous-runs.md); --next prints the next step
./scripts/test-autopilot.sh              # tests for scripts/autopilot.sh
specify check                            # Spec Kit CLI, installed with uv tool install specify-cli --from git+https://github.com/github/spec-kit.git; its skills are /speckit-*
flutter test integration_test            # smoke test on a running device
```

`pubspec.lock`, `Gemfile.lock` (fastlane), and `firestore-tests/package-lock.json` are committed. Other `*.lock` files are git-ignored.
