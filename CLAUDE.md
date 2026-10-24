# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Goal

A mobile app (iOS + Android) for pet owners to track their pets' health symptoms. The first priority is **fast symptom logging**: capturing what happened and when, with as little friction as possible. The audience is pet owners in general, not just a single household.

## Working rules

- Don't invent scope or a roadmap. Never label something "out of scope for v1", "planned for later", "v2", or similar unless the user has said so. When the user makes a choice, record only that choice. Don't add features, phases, or future work they didn't ask for, in docs, code comments, or replies.
- Every push to `main` ships to testers. Keep each commit one small, complete change that is safe to release on its own.
- Every behavior change comes with tests: unit and widget tests in `test/`, security rules tests in `firestore-tests/`. Write the failing test first when practical.
- Run `./scripts/check.sh` before committing, and never push with failing checks. Don't bypass the pre-push hook (`--no-verify`).
- The coverage minimum in `scripts/coverage.sh` only goes up. The check fails when coverage is more than 0.2% above it, so raise it then; never lower it to get a change through.

## Workflow

Each commit goes through these steps. Hooks and checks enforce steps 3 to 6, and that a change to `lib/` comes with test changes; planning and writing the test first are up to you. `docs/design/dev-workflow/README.md` has the details.

1. **Plan.** Work that takes several commits gets a design README in `docs/design/` with the user's decisions and a build order, one commit per step.
2. **Test and change.** Write the failing test, then the change, then run `./scripts/check.sh`.
3. **Stage** exactly what the commit will hold.
4. **Review** with the `targeted-review` skill. `./scripts/required-reviewers.sh` names the reviewer agents (`.claude/agents/`) the staged change needs, and they run in parallel. Fix what they find, stage the fixes, and continue the reviewers whose paths changed. Don't stage while reviewers run.
5. **Commit** with `git commit -q -m "<type>: <subject>"`. The commit gate (`.claude/hooks/review-gate.sh`) denies it until every required reviewer has passed the staged diff, and allows only `-m`, `-q`, `-s`, `-v`, `--amend`, `--no-edit`, `--allow-empty` and `--dry-run`. `git commit --dry-run -q -m x` names the reviewers still missing.
6. **Push** to `main`. The pre-push hook runs `check.sh`. CI runs it again, checks the pushed commits with `scripts/tests-changed.sh`, and runs the integration tests before anything deploys.

## Project state

Flutter app (package `pet_health_tracker`, org `com.pootzandboogie` (Pootz&Boogie, the author's hobby-project label), iOS + Android only). Google sign-in, Apple sign-in (iOS only), creating, joining (invite codes), switching, renaming, leaving, transferring and deleting households, member names and the members list, deleting an account, adding and editing pets, the home screen with recent logs and a "Log a symptom" sheet (catalog and `other` symptoms), a per-pet history with editing and deleting, and the symptom catalog (bundled and published, labelling logs) are implemented (`lib/core`, `lib/data`, `lib/features`). Crashlytics reports crashes from release builds.

## CI

`.github/workflows/release.yml` runs `scripts/check.sh` and the integration tests on an Android emulator on every push to `main`, then deploys Firestore rules and uploads to the Play internal testing track (fastlane, `android/fastlane/`). Deploy jobs are gated by repo variables (`FIRESTORE_RULES_DEPLOY_ENABLED`, `ANDROID_DEPLOY_ENABLED`, `IOS_DEPLOY_ENABLED`). Android deploys are on and roll out straight to internal testers; iOS deploys are on and upload to TestFlight (`ios/fastlane/`). Setup steps and secrets are in `docs/ci.md`.

## Design docs

Stack, auth approach, and Firestore schema (with open questions) are in `docs/architecture.md` and `docs/data-model.md`. Reviewer agents (`.claude/agents/`) and the commit gates are described in `docs/design/dev-workflow/README.md`, with its build order showing which steps are done. Google sign-in, Apple sign-in on iOS, creating, joining, switching, renaming, leaving, transferring and deleting households, the members list, adding and editing pets, logging catalog and `other` symptoms from the home sheet, editing and deleting logs, and the symptom catalog are implemented; the rest is still a plan. Keep them updated when decisions change or a planned piece ships.

## Commands

```
git config core.hooksPath .githooks      # once per clone: run checks before every push
flutter pub get                          # install dependencies
flutter run                              # run on a connected device/emulator
./scripts/check.sh                       # everything CI checks: format, analyze, tests, size limits, comment phrases, tests changed with lib/, coverage, hook tests, reviewer-mapping tests, review-gate tests, rules tests
flutter test                             # run all Flutter tests
flutter test test/auth_gate_test.dart    # run a single test file
flutter test --plain-name "<test name>"  # run a single test by name
npm --prefix firestore-tests test        # security rules and publish-catalog tests (starts the Firestore emulator on 8180)
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
./scripts/publish-catalog.sh             # publish assets/catalog/symptoms.json to Firestore (needs gcloud application-default login)
./scripts/backfill-owners.sh [--apply]   # give households made before owners an ownerId (lists only, without --apply)
flutter test integration_test            # smoke test and repository tests against the real rules, on a running device; needs the Firebase emulators up
```

`pubspec.lock`, `Gemfile.lock` (fastlane), and `firestore-tests/package-lock.json` are committed. Other `*.lock` files are git-ignored.
