# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Goal

A mobile app (iOS + Android) for pet owners to track their pets' health symptoms. The first priority is **fast symptom logging**: capturing what happened and when, with as little friction as possible. The audience is pet owners in general, not just a single household.

## Working rules

- Don't invent scope or a roadmap. Never label something "out of scope for v1", "planned for later", "v2", or similar unless the user has said so. When the user makes a choice, record only that choice. Don't add features, phases, or future work they didn't ask for, in docs, code comments, or replies.
- Every push to `main` ships to testers. Keep each commit one small, complete change that is safe to release on its own.
- Every behavior change comes with tests: unit and widget tests in `test/`, security rules tests in `firestore-tests/`. Write the failing test first when practical.
- Run `./scripts/check.sh` before committing, and never push with failing checks. Don't bypass the pre-push hook (`--no-verify`).
- The coverage minimum in `scripts/coverage.sh` only goes up. Raise it when coverage rises; never lower it to get a change through.

## Project state

Flutter app (package `pet_health_tracker`, org `com.pootzandboogie` (Pootz&Boogie, the author's hobby-project label), iOS + Android only). Google sign-in, household creation, adding and editing pets, and logging and editing `other` symptoms with a per-pet history are implemented (`lib/core`, `lib/data`, `lib/features`). Crashlytics reports crashes from release builds.

## CI

`.github/workflows/release.yml` runs `scripts/check.sh` and an Android emulator smoke test on every push to `main`, then deploys Firestore rules and uploads to the Play internal testing track (fastlane, `android/fastlane/`). Deploy jobs are gated by repo variables (`FIRESTORE_RULES_DEPLOY_ENABLED`, `ANDROID_DEPLOY_ENABLED`, `IOS_DEPLOY_ENABLED`). Android deploys are on and roll out straight to internal testers; iOS is a build check only until the Apple Developer account exists. Setup steps and secrets are in `docs/ci.md`.

## Design docs

Stack, auth approach, and Firestore schema (with open questions) are in `docs/architecture.md` and `docs/data-model.md`. Google sign-in, household creation, adding and editing pets, and logging and editing `other` symptoms are implemented; the rest is still a plan. Keep them updated when decisions change or a planned piece ships.

## Commands

```
git config core.hooksPath .githooks      # once per clone: run checks before every push
flutter pub get                          # install dependencies
flutter run                              # run on a connected device/emulator
./scripts/check.sh                       # everything CI checks: format, analyze, tests, coverage, rules tests
flutter test                             # run all Flutter tests
flutter test test/auth_gate_test.dart    # run a single test file
flutter test --plain-name "<test name>"  # run a single test by name
npm --prefix firestore-tests test        # security rules tests (starts the Firestore emulator on 8180)
flutter test integration_test            # smoke test on a running device; needs the Firebase emulators up
```

`pubspec.lock`, `Gemfile.lock` (fastlane), and `firestore-tests/package-lock.json` are committed. Other `*.lock` files are git-ignored.
