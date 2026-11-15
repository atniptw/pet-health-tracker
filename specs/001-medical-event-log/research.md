# Research: Medical Event Log

Decisions for `plan.md`. The stack is fixed (Flutter + Firebase, the existing project, bundle IDs, signing and CI); everything below is what this feature needs on top of it.

## 1. Where records live before signing in

- **Decision**: A local SQLite database on the phone, through `sqflite` (2.4.x). Firestore and Firebase Auth are not used by this feature, and `firestore.rules` stays deny-all.
- **Rationale**: The spec says records live only on the phone until the caregiver signs in (Assumptions), logging must work offline (FR-012) and nothing may be lost (SC-004). SQLite writes are transactional and durable, and work without a network by nature. Keeping Firestore out of this feature also means nothing depends on rules that are off during the rebuild.
- **Alternatives considered**:
  - *Firestore with offline persistence and anonymous auth*: puts records in the cloud before the caregiver signs in, which the spec rules out, and the offline cache is a cache, not a guaranteed store.
  - *drift*: a good SQLite layer with reactive queries, but it generates code into `lib/`, which would count against the 100% coverage minimum and the size limits. The schema here is four small tables, so hand-written queries are short.
  - *A JSON file or shared_preferences*: no transactions, so a crash mid-write can lose the record.

## 2. How the UI sees changes

- **Decision**: Repository interfaces (`contracts/repositories.md`) whose `watch…` methods return `Stream`s. The local implementations re-emit after every write they make. Screens read them with `StreamBuilder`. Repositories reach widgets through one `InheritedWidget` (`AppScope`) built in `main.dart`.
- **Rationale**: Flutter's own widgets cover it with no state-management package. The interfaces are also the seam spec 002 needs: a signed-in household can be backed by another implementation without the screens changing.
- **Alternatives considered**: `provider`, `riverpod`, `bloc`: each adds a dependency and concepts that four screens of streams don't need.

## 3. Identifiers

- **Decision**: Pets, custom event types and events get random UUID v4 strings (`uuid` 4.x) created on the phone. Built-in event types have fixed ids such as `vomiting`.
- **Rationale**: Ids made on the phone need no server, and stay unique when the records later move into a household (spec 002, SC-004: nothing duplicated).
- **Alternatives considered**: SQLite auto-increment ids: unique only on one phone.

## 4. Storing time

- **Decision**: Each event stores the moment it happened as UTC milliseconds since the epoch. It is shown in the phone's current local time with `intl`'s `DateFormat` (0.20.x).
- **Rationale**: Covers the time-zone edge case: the moment stays fixed and the display follows the phone.
- **Validation**: The date and time pickers stop at now, and saving re-checks against the clock at the moment of saving, so a future time is refused (edge case). A time a minute ahead because the picker was opened earlier is refused with the same message.

## 5. Built-in event types and their detail questions

The spec leaves the exact list to the plan. It is the list from the spec's Assumptions, in this order, with the details a vet usually asks about. Each question is optional.

| Id | Name | Detail questions |
|----|------|------------------|
| `vomiting` | Vomiting | What came up: Food, Yellow liquid or bile, Foam, Hairball, Blood, Something else |
| `diarrhea` | Diarrhea | Consistency: Soft, Watery · Blood seen: Yes, No |
| `seizure` | Seizure | Kind: Focal, Grand mal · How long it lasted (duration) |
| `coughing` | Coughing | How long it lasted (duration) |
| `sneezing` | Sneezing | none |
| `limping` | Limping | Which leg: Front left, Front right, Back left, Back right |
| `not_eating` | Not eating | Meals missed: 1, 2, 3 or more |
| `lethargy` | Lethargy | none |
| `scratching` | Scratching | none |
| `accident` | Accident in the house | What: Urine, Stool, Both |
| `wound` | Wound | none |

- **Question kinds**: two are enough for this list: *choice* (pick one option) and *duration* (minutes and seconds). Anything else goes in the free-text note (FR-006).
- **Questions are data, and their kind drives the UI**: the user wants adding questions to stay easy. Each type's questions are a list of values in `lib/domain/built_in_event_types.dart`. Each kind is a subclass of a sealed `DetailQuestion` that owns its own rules: which answers it accepts and how an answer is written out in the history. The UI turns each kind into its input widget with one exhaustive `switch`. So:
  - a question of an existing kind is one entry in the list, with no change to screens, storage or validation;
  - a new kind is one `DetailQuestion` subclass and one input widget, and the compiler points to every `switch` that has to handle it.
- **Answers are stored generically**: an event's `details` is a JSON object from question id to answer, so a new question needs no schema change.
- **Ids are stable**: question and option ids never change and are never reused, while labels can. A stored answer keeps its meaning whatever the label says.
- **In code, not in the database**: definitions ship with the app, so the compiler and tests check every one. Storing them in the database would let them change without a new build, but every change still needs a release for the screens that show them, and nothing could check the definitions before they reach a phone.
- **Custom types** (entered in the caregiver's own words) have no detail questions, only the note.
- **Rationale**: Short questions, each one tap, keep logging fast (principle I) while capturing what the spec's example asks for (how long a seizure lasted).

## 6. Species

- **Decision**: Dog, Cat, Other. Stored as a fixed id; "Other" has no free text.
- **Rationale**: The user's decision (2026-11-14). The built-in event types (§5) are the events vets commonly see in dogs and cats. Naming other species would need research into which medical events are noteworthy for each, so any other animal is "Other". The spec asks for common species with an "other" option, and nothing in it depends on the species beyond showing it.

## 7. Matching typed event types

- **Decision**: A typed name is trimmed, its inner runs of spaces collapsed to one, and compared case-insensitively (`toLowerCase()`) against every built-in and custom type, including removed ones. A match uses that type (and un-removes it if it was removed); otherwise a new custom type is created when the event is saved, keeping the caregiver's capitalization.
- **Rationale**: Covers the capitalization edge case and FR-004 (typing a removed type again brings it back and its events count together).

## 8. Frequency figures

- **Time since previous** (FR-009): for each event, the gap to the latest earlier event of the same type for the same pet, over the pet's whole history. The oldest event of a type shows nothing.
- **Periods** (FR-010): rolling windows ending now: last 30 days, last 90 days (default), last 12 months (same date and time one year back) or all time.
- **Count**: events of the type whose moment falls in the period.
- **Average time between**: (newest − oldest) ÷ (count − 1) over the events in the period, shown only when the count is 2 or more (story 2 scenario 4). The same functions serve the vet view (spec 003, FR-005).
- **Last one**: each type's summary also shows how long ago its newest event was, which is what SC-003 asks a caregiver to find.
- **Showing durations**: under an hour in minutes, under 2 days in hours, otherwise in days; averages over 2 days get one decimal (for example "every 3.5 days").
- **Where it runs**: plain Dart functions over the events already loaded for a pet, so they are unit-tested without a database. Hundreds of events per pet is well within what a list scan handles at once.

## 9. Picking the pet when logging

- **Decision**: The app stores the id of the pet the caregiver last saved a new event for (a row in a `settings` table, written in the same transaction as the event). On opening the log screen: one active pet → that pet, with no picker (FR-007); several → the stored pet if it is active, otherwise none. Editing an event's pet doesn't change it.
- **Rationale**: The spec says "the pet they most recently logged for", which is the act of logging, not the event's time: an event back-dated to last week still makes its pet the last logged for.

## 10. Testing

- **Decision**: `flutter_test` for unit and widget tests, with `sqflite_common_ffi` (2.4.x) giving the repositories a real in-memory SQLite database on the test host (macOS locally, `ubuntu-latest` in CI). The integration smoke test runs the real app on the emulator in CI with the real `sqflite` plugin.
- **Rationale**: Tests exercise the real SQL, which is what could lose records. The coverage minimum is 100%, so every file in `lib/` except `main.dart` and `firebase_options.dart` is covered by these tests.
- **Check**: The first task that adds `sqflite_common_ffi` confirms the tests run on `ubuntu-latest`; its `sqlite3` dependency provides the native library.
- **Layers**: pure Dart tests for the domain; repository tests on real SQLite; widget tests per screen on the real repositories over in-memory SQLite (no mocks, so screens and store can't drift apart); one journey test per story in `test/journeys/` that runs the whole `App` through the story's independent test; the device smoke test stays thin, because CI runs it only after merging to `main`.
- **Built for Claude to iterate on**: tests are the spec in executable form, and each task's "done" is a command's exit code rather than a judgment.
  - *Spec ids in test names* (`001-US1-S3`, `001-FR-003`, `001-EC-01`, `001-SC-001`). `scripts/spec-coverage.sh` lists every id in the spec that no test names and no `untested.md` line explains, and fails on ids that don't exist. A task is done when the ids it covers are covered; the feature is done when none are missing (`--strict`, run by `check.sh` once every task is ticked).
  - *One quiet test command*: `scripts/test.sh` runs `flutter test` with the failures-only reporter, so a run prints only what's wrong, and sets one time zone (`America/Chicago`, not UTC) so local and CI runs agree and time-zone bugs show up. A test fails with a pointer to `scripts/test.sh` when it's run without it.
  - *Fixed clock and ids* in every test, through the repositories' `Clock` and `IdGenerator`.
  - *Shared helpers* in `test/support/`: a robot that speaks the spec's language (`addPet`, `logEvent`, `openHistory`), and `expectAccessible`, called in every screen's tests, so SC-002 is checked as each screen is built rather than at the end.
  - *Stop rules* in `CLAUDE.md`, so a stuck loop ends in a question to the user instead of more attempts or a weakened test.
- **Left out**: golden (screenshot) tests, which differ between macOS and Linux font rendering; mocking libraries; mutation testing, which costs more time per run than it saves here.

## 11. Ease of use

- Tap targets at least 48 dp, labels in words (not icons alone), text that grows with the phone's font size setting, and screen-reader labels on every control (SC-002).
- One action per screen where possible: the log screen is the home screen, and logging an event for the picked pet is two taps (the type, then Save), within SC-001's three.
- Deleting an event asks for confirmation (FR-011).
