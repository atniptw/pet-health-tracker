# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Goal

A mobile app (iOS + Android) for pet owners to track their pets' health symptoms. The first priority is **fast symptom logging**: capturing what happened and when, with as little friction as possible. The audience is pet owners in general, not just a single household.

## Working rules

- Don't invent scope or a roadmap. Never label something "out of scope for v1", "planned for later", "v2", or similar unless the user has said so. When the user makes a choice, record only that choice. Don't add features, phases, or future work they didn't ask for, in docs, code comments, or replies.

## Project state

Flutter app (package `pet_health_tracker`, org `com.pootzandboogie` (Pootz&Boogie, the author's hobby-project label), iOS + Android only). Google sign-in and household creation are implemented (`lib/core`, `lib/data`, `lib/features`); widget tests live in `test/`.

## CI

`.github/workflows/release.yml` runs `flutter analyze` and `flutter test` on every push to `main`, then deploys to the Play internal testing track (fastlane, `android/fastlane/`). Deploy jobs are gated by repo variables (`ANDROID_DEPLOY_ENABLED`, `IOS_DEPLOY_ENABLED`). Android deploys are on and roll out straight to internal testers; iOS is a build check only until the Apple Developer account exists. Setup steps and secrets are in `docs/ci.md`.

## Design docs

Stack, auth approach, and Firestore schema (with open questions) are in `docs/architecture.md` and `docs/data-model.md`. Google sign-in and household creation are implemented; the rest is still a plan. Keep them updated when decisions change or a planned piece ships.

## Commands

```
flutter pub get                          # install dependencies
flutter run                              # run on a connected device/emulator
flutter analyze                          # lint (rules in analysis_options.yaml)
flutter test                             # run all tests
flutter test test/auth_gate_test.dart    # run a single test file
flutter test --plain-name "<test name>"  # run a single test by name
```

`*.lock` is git-ignored, so `pubspec.lock` is not committed. `Gemfile.lock` is the exception (it pins fastlane).
