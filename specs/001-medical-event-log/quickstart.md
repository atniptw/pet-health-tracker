# Quickstart: Medical Event Log

How to check the feature works, automatically and by hand. Screen behavior is in `contracts/screens.md`, rules in `data-model.md`.

## Prerequisites

```
git config core.hooksPath .githooks
flutter pub get
```

An Android emulator or iOS simulator for the manual run and the integration test.

## Automated checks

```
./scripts/check.sh                                  # everything CI checks, coverage at 100%
./scripts/test.sh test/journeys                     # each story end to end, in seconds
./scripts/test.sh test/domain test/data test/ui     # units, repositories, screens
./scripts/spec-coverage.sh specs/001-medical-event-log   # spec ids with no test
flutter test integration_test                       # on a running device
```

Expected: all pass, with no file in `lib/` (other than `main.dart` and `firebase_options.dart`) below 100% line coverage, and `spec-coverage.sh` reporting no missing ids.

## Manual run

`flutter run` on a fresh install (or after clearing the app's data), then:

| # | Do | Expect | Covers |
|---|----|--------|--------|
| 1 | Open the app | "Add your first pet" | Story 3.1 |
| 2 | Add "Rex", Dog | Log screen with "Rex" as the heading, no pet picker | Story 3, FR-007 |
| 3 | Tap Vomiting, then Save | "Saved: Vomiting for Rex"; two taps in all | Story 1.1, SC-001 |
| 4 | Tap Seizure, answer "How long it lasted" 2 min, Save | Saved with the duration | Story 1.7 |
| 5 | Tap Vomiting, set When to yesterday 08:00, Save | Saved at that time | Story 1.4 |
| 6 | Tap Vomiting, try to set a time later today than now | When keeps its value, with "That time is in the future" under it (D-007) | FR-003 |
| 7 | "Something else", type "Ear shaking", Save; open a new log | "Ear shaking" is in the grid | Story 1.5 |
| 8 | "Something else", type "ear SHAKING", Save | Saved as "Ear shaking", counted with the earlier one in History | Edge case |
| 9 | History | Newest first; the later Vomiting shows the gap since yesterday 08:00; the summary for 90 days shows Vomiting "2 times" | Story 2.1–2.3 |
| 10 | Switch the period to 30 days, 12 months, All time | Counts follow the period | FR-010 |
| 11 | Open the Seizure event | No gap shown; add a note, Save; it shows in the history | Story 2.4, 1.8 |
| 12 | Open the yesterday Vomiting, change its time to 3 days ago, Save | Gaps and average update | Story 4.1 |
| 13 | Open an event, Delete, confirm | Gone from the list and the counts | Story 4.2 |
| 14 | Pets → Add pet "Mia", Cat; back to Log | Pet choices shown, Rex picked (last logged for) | Story 1.2 |
| 15 | Pick Mia, log Sneezing; reopen the app | Mia picked | FR-007 |
| 16 | Mia's history → Archive | Log shows Rex only, no picker | Story 3.3, edge case |
| 17 | Pets → Archived pets → Mia → Restore | Pet choices back, with Mia picked (still the last logged for) and her history intact | Story 3.4 |
| 18 | Menu → My event types → Remove "Ear shaking" | Gone from the grid; its event still shows "Ear shaking" in the history | Story 1.9 |
| 19 | "Something else", type "Ear shaking", Save | Offered again; History counts both events together | Edge case, FR-004 |
| 20 | Turn on airplane mode, log an event, force-quit and reopen | The event is there | FR-012, SC-004 |
| 21 | Change the phone's time zone | Times shown move with the zone; gaps stay the same | Edge case |
| 22 | Archive every pet | "Add your first pet" with "See archived pets" | Edge case |
