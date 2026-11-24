# Implementation Plan: Medical Event Log

**Branch**: `001-medical-event-log` | **Date**: 2026-11-14 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/001-medical-event-log/spec.md`

## Summary

A caregiver adds their pets, logs medical events for them in two taps (type, then Save) with the time defaulting to now, adds optional details and a note, and sees each pet's history newest first with the time since the previous event of the same type and, per type, the count, average time between and last time over 30 days, 90 days, 12 months or all time. Pets can be archived and restored, custom event types removed from the list, and events edited or deleted.

Everything is stored in a local SQLite database on the phone (`sqflite`), so it works offline and without signing in. Screens read repository streams; the repositories are interfaces so spec 002 can back a signed-in household with another store. Frequency figures are plain Dart functions shared with the vet view (spec 003). Details in `research.md`.

## Technical Context

**Language/Version**: Dart 3.13 (SDK `^3.13.4`), Flutter 3.47.5 stable

**Primary Dependencies**: Flutter (Material 3), `sqflite` 2.4.x, `uuid` 4.x, `intl` 0.20.x, `path` 1.9.x, `characters` 1.4.x (names counted in user-perceived characters); existing `firebase_core` and `firebase_crashlytics` unchanged. Dev: `sqflite_common_ffi` 2.4.x

**Storage**: SQLite on the phone (`data-model.md`). Firestore is not used; `firestore.rules` stays deny-all.

**Testing**: `flutter_test` unit, widget and per-story journey tests in `test/` (repositories on in-memory SQLite via `sqflite_common_ffi`), run through `scripts/test.sh`; the integration smoke test in `integration_test/`. Test names carry the spec's ids, and `scripts/spec-coverage.sh` reports any id without a test (research §10). No rules tests change.

**Target Platform**: iOS and Android phones, at the project's existing minimum OS versions

**Project Type**: Mobile app (Flutter, single package)

**Performance Goals**: Log a common event in under 10 seconds and at most 3 taps from opening the app (SC-001)

**Constraints**: Works fully offline and signed out (FR-012, FR-014); no logged event lost (SC-004); usable by people not comfortable with apps (SC-002: large tap targets, words not icons alone, font scaling, screen-reader labels); 100% line coverage, 300 lines per file and 40 per function in `lib/`

**Scale/Scope**: One caregiver on one phone, a handful of pets, hundreds to a few thousand events; 9 screens (`contracts/screens.md`)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-checked after Phase 1 design.*

| Principle | Check | Status |
|-----------|-------|--------|
| I. Fast medical event logging | The log screen is the home screen, the pet is picked for the caregiver, and only the type is required: two taps for a common event. Only medical events and pets are stored (FR-013). | Pass |
| II. Only what was asked | Every screen and field traces to a story or FR. The built-in type list, its detail questions and the species list are choices the spec leaves to the plan (Assumptions), listed in `research.md` §5–6 for the user to review. No sign-in, sharing or vet view in this feature. | Pass |
| III. Every commit ships (rebuild period) | Deploys are off. Each task in `tasks.md` builds, passes `check.sh` and leaves a working app: the placeholder screen is replaced only by the task that lets a caregiver add a pet and log an event, and later tasks add whole behaviors. No rules or Firestore change, so nothing touches stored cloud data. Built from the specs alone, without reading `pre-rebuild`. | Pass |
| IV. Tests with every behavior change | Each task brings unit, repository or widget tests, written first where practical. No rules paths are added, so no new rules tests. | Pass |
| V. Checks are never bypassed | 100% coverage kept by testing every `lib/` file; files and functions kept under the size limits rather than baselined; commits through the review gate. | Pass |

**Post-design re-check**: Pass. The design adds no Firestore paths, no generated code in `lib/`, and no screens beyond the spec's stories.

## Project Structure

### Documentation (this feature)

```text
specs/001-medical-event-log/
├── spec.md
├── plan.md              # this file
├── research.md          # decisions
├── data-model.md        # entities, rules, SQLite schema
├── quickstart.md        # how to check it works
├── contracts/
│   ├── repositories.md  # data interfaces the screens use
│   └── screens.md       # what each screen shows and does
├── checklists/requirements.md
├── untested.md          # spec ids, or parts of them, no automated test can check, with reasons
└── tasks.md             # written by /speckit-tasks
```

### Source Code (repository root)

```text
lib/
├── main.dart                     # opens the database, builds AppScope, runApp
├── app.dart                      # MaterialApp, theme, start screen choice
├── firebase_options.dart         # generated, unchanged
├── domain/
│   ├── names.dart                # name length check (D-001)
│   ├── pet.dart                  # Pet, Species
│   ├── event_type.dart           # EventType, DetailQuestion, match key
│   ├── built_in_event_types.dart # research §5
│   ├── medical_event.dart        # MedicalEvent, detail validation
│   ├── frequency.dart            # Period, timeSincePrevious, TypeSummary
│   └── durations.dart            # how gaps are written out
├── data/
│   ├── repositories.dart         # interfaces, TypeChoice, Clock, IdGenerator
│   └── local/
│       ├── database.dart         # open, schema, foreign keys
│       ├── change_signal.dart    # streams that read again after each write
│       ├── local_pet_repository.dart
│       ├── local_event_type_repository.dart
│       └── local_event_repository.dart
└── ui/
    ├── app_scope.dart            # InheritedWidget holding the repositories
    ├── log/                      # home screen, pet choices, type grid, log sheet, "Something else"
    ├── history/                  # pet history, summary, event tile, event screen
    ├── pets/                     # first pet, pet form, pets, archived pets
    ├── types/                    # my event types
    └── common/                   # shared fields (date/time, duration, detail questions, event fields), WatchedView and ActivePetsAndTypes for reads, read-failure reporting, centered message

test/
├── domain/                       # pure unit tests
├── data/                         # repositories on in-memory SQLite
├── ui/                           # widget tests per screen
├── journeys/                     # one test per story, the whole App through the story
├── support/                      # test database, test app, robot, expectAccessible, time zone guard
├── app_test.dart                 # start screen choice
└── tool/                         # existing

scripts/
├── test.sh                       # the one test command: fixed time zone, failures only
└── spec-coverage.sh              # spec ids with no test

integration_test/
└── app_smoke_test.dart           # boots the real app: first pet, log one event
```

**Structure Decision**: One Flutter package. `domain/` holds pure Dart types and calculations with no Flutter or database imports, `data/` the repository interfaces and their SQLite implementations, and `ui/` the widgets, grouped by screen area. Tests mirror these folders.

## Docs this feature keeps true

- `CLAUDE.md` *Project state* and *Specs and design docs*: updated by the task that replaces the placeholder screen (T024), and *Specs and design docs* again as the feature completes (T035).
- `specs/001-medical-event-log/tasks.md`: each task ticked in its own commit.
- The integration smoke test and `test/app_test.dart` change with the start screen.

## Complexity Tracking

No constitution violations to justify.
