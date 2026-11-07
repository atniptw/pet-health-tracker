# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Goal

A mobile app (iOS + Android) for pet owners to track their pets' health symptoms. The first priority is **fast symptom logging**: capturing what happened and when, with as little friction as possible. The audience is pet owners in general, not just a single household.

## Rules and workflow

The project is a [Spec Kit](https://github.com/github/spec-kit) project. Its rules and workflow are in the constitution, `.specify/memory/constitution.md`: only what was asked, every commit ships, tests with every behavior change, checks are never bypassed, and one reviewed commit per task on a feature branch, rebase-merged to `main` through a pull request. The `/speckit-*` skills write each feature's `spec.md`, `plan.md` and `tasks.md` under `specs/`.

Each commit is staged exactly, reviewed with the `targeted-review` skill, and made with `git commit -q -m "<type>: <subject>"`. The commit gate (`.claude/hooks/review-gate.sh`) denies it until every reviewer `./scripts/required-reviewers.sh` names has passed the staged diff, and allows only `-m`, `-q`, `-s`, `-v`, `--amend`, `--no-edit`, `--allow-empty` and `--dry-run`. `git commit --dry-run -q -m x` names the reviewers still missing. Don't stage while reviewers run. The pre-push hook runs `check.sh` on every push, and CI runs it again with `scripts/tests-changed.sh` and the integration tests on every push to `main` before anything deploys. `specs/002-dev-workflow/plan.md` has the details.

## Project state

Flutter app (package `pet_health_tracker`, org `com.pootzandboogie` (Pootz&Boogie, the author's hobby-project label), iOS + Android only). Google sign-in, Apple sign-in (iOS only), creating, joining (invite codes), switching, renaming, leaving, transferring and deleting households, member names, the members list, removing members and changing roles, deleting an account, adding, editing and archiving pets, the home screen with recent logs and a "Log a symptom" sheet (catalog and `other` symptoms), a per-pet history with editing and deleting, and the symptom catalog (bundled and published, labelling logs) are implemented (`lib/core`, `lib/data`, `lib/features`). Crashlytics reports crashes from release builds.

## CI

`.github/workflows/release.yml` runs `scripts/check.sh` and the integration tests on an Android emulator on every push to `main`, then deploys Firestore rules and uploads to the Play internal testing track (fastlane, `android/fastlane/`). Deploy jobs are gated by repo variables (`FIRESTORE_RULES_DEPLOY_ENABLED`, `ANDROID_DEPLOY_ENABLED`, `IOS_DEPLOY_ENABLED`). Android deploys are on and roll out straight to internal testers; iOS deploys are on and upload to TestFlight (`ios/fastlane/`). Setup steps and secrets are in `docs/ci.md`.

## Specs and design docs

Stack, auth approach, and Firestore schema (with open questions) are in `docs/architecture.md` and `docs/data-model.md`. Each feature's spec, plan and tasks are in `specs/NNN-name/`, with its tasks showing which are done. Reviewer agents (`.claude/agents/`) and the commit gates are described in `specs/002-dev-workflow/plan.md`. Google sign-in, Apple sign-in on iOS, creating, joining, switching, renaming, leaving, transferring and deleting households, the members list, removing members and changing roles, adding, editing and archiving pets, logging catalog and `other` symptoms from the home sheet, editing and deleting logs, and the symptom catalog are implemented; the rest is still a plan. Keep them updated when decisions change or a planned piece ships.

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
specify check                            # Spec Kit CLI, installed with uv tool install specify-cli --from git+https://github.com/github/spec-kit.git; its skills are /speckit-*
flutter test integration_test            # smoke test and repository tests against the real rules, on a running device; needs the Firebase emulators up
```

`pubspec.lock`, `Gemfile.lock` (fastlane), and `firestore-tests/package-lock.json` are committed. Other `*.lock` files are git-ignored.
