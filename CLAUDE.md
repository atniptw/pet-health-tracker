# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Goal

A mobile app (iOS + Android) for pet owners to track their pets' health symptoms. The first priority is **fast symptom logging**: capturing what happened, when, and how severe, with as little friction as possible. Trend views and vet-visit reports are later goals. The audience is pet owners in general, not just a single household, so accounts and onboarding will eventually matter.

## Project state

Freshly scaffolded Flutter app (package `pet_health_tracker`, org `com.pootzandboogie` (Pootz&Boogie, the author's hobby-project label), iOS + Android only). `lib/main.dart` and `test/widget_test.dart` are still the default counter-app template. There is no real architecture yet; update this file as one emerges.

## Design docs

Planned stack, auth approach, and Firestore schema (with open questions) are in `docs/architecture.md` and `docs/data-model.md`. They describe a plan, not implemented code. Keep them updated when decisions change.

## Commands

```
flutter pub get                          # install dependencies
flutter run                              # run on a connected device/emulator
flutter analyze                          # lint (rules in analysis_options.yaml)
flutter test                             # run all tests
flutter test test/widget_test.dart       # run a single test file
flutter test --plain-name "<test name>"  # run a single test by name
```

`*.lock` is git-ignored, so `pubspec.lock` is not committed.
