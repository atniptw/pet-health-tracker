---

description: "Tasks for the medical event log"
---

# Tasks: Medical Event Log

**Input**: Design documents from `specs/001-medical-event-log/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/repositories.md, contracts/screens.md, quickstart.md

**Tests**: The constitution (principle IV) requires tests with every behavior change, and coverage stays at 100%. Each task is one commit that includes its own tests, written first.

## How to do a task

Each task is one commit (constitution, Workflow 3). Phase 1 builds the loop below; from T005 on, every task follows it. T003 and T004 already add their `build-log.md` rows (step 4), and Phase 1 merges after T004 (step 5). `CLAUDE.md` (*Implementing a task*, T004) holds the same loop and its stop rules, and `docs/dev-workflow/autonomous-runs.md` the stop rules for an autonomous run.

1. **Read** the task, and the spec sentences behind each id on its **Covers** line.
2. **Test first**: write the tests, putting each covered id in a test's name, for example `testWidgets('001-US1-S3: several pets, none logged for → no pet picked', …)`. Use the wording in `contracts/screens.md` and the helpers in `test/support/`. Run `./scripts/test.sh <test files>` and see each new test fail for the reason the spec gives.
3. **Build** until `./scripts/test.sh <test files>` passes, then run `./scripts/check.sh`.
4. **Done** when `./scripts/spec-coverage.sh specs/001-medical-event-log` lists each id on the task's Covers line as covered, `check.sh` passes, and the `targeted-review` skill passes on the staged task. Tick the task here and add its row to `build-log.md` before staging, since the commit gate accepts only the diff that was reviewed. Then commit with `git commit -q -m "<type>: <subject>"`.
5. **Merge** after the last task of each phase: push the branch and open a pull request with `gh`, and rebase-merge it to `main`, where CI runs `check.sh` and the integration tests.

The placeholder screen stays until T024 wires in the first complete flow. Screens built before then are tested but not reachable. During the rebuild period, don't read the `pre-rebuild` tag or earlier history for how to build anything (constitution III).

**Covers ids**: `001-US<story>-S<scenario>` for the spec's acceptance scenarios (numbered in order under each story), and `001-FR-NNN`, `001-EC-NN` and `001-SC-NNN` for its requirements, edge cases and success criteria.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies on incomplete tasks)
- **[Story]**: Which user story this task belongs to (US1–US4)

## Path Conventions

One Flutter package: `lib/domain/`, `lib/data/`, `lib/ui/`, with tests mirroring them in `test/`, journey tests in `test/journeys/` and shared helpers in `test/support/` (plan.md, Project Structure).

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Dependencies, and the commands that tell Claude quickly and exactly whether a task is done

- [X] T001 Add `sqflite: ^2.4.6`, `uuid: ^4.6.0`, `intl: ^0.20.3` and `path: ^1.9.1` to `dependencies` and `sqflite_common_ffi: ^2.4.7` to `dev_dependencies` in `pubspec.yaml`, run `flutter pub get` and commit `pubspec.lock`. Add `test/support/test_database.dart` with `Future<Database> openTestDatabase()` that calls `sqfliteFfiInit()` and opens `inMemoryDatabasePath` with `databaseFactoryFfi` (no schema yet), and `test/support/test_database_test.dart` checking `SELECT sqlite_version()` returns a value. Merge this task's PR before starting the rest, so the CI run on `ubuntu-latest` confirms `sqflite_common_ffi` works there (research §10). Commit type `build:`.
- [X] T002 Add `scripts/test.sh [<flutter test args>…]`, the one command for running tests: it sets `TZ=America/Chicago` and runs `flutter test --reporter failures-only` with the given arguments (all tests when none), then prints one line, `tests passed` or `tests failed`. Change the test step in `scripts/check.sh` to `./scripts/test.sh --coverage`. Add `test/support/time_zone_test.dart`, which fails with "Run tests with ./scripts/test.sh, which sets the time zone" unless `DateTime(2026, 1, 1).timeZoneOffset` is −6 hours, so local and CI runs see the same zone (research §10). Add `scripts/test-test-sh.sh` (passing and failing runs, and the summary line) and call it from `check.sh`'s test step. In `CLAUDE.md` *Commands*, list `./scripts/test.sh` and say to use it instead of `flutter test` for `test/`.
- [X] T003 Add `scripts/spec-coverage.sh <spec dir>…`, which answers whether every sentence of a spec is tested (research §10). From `spec.md` it reads the ids `NNN-US<n>-S<m>` (numbered acceptance scenarios under `### User Story <n>`), `NNN-FR-NNN`, `NNN-EC-NN` and `NNN-SC-NNN`, where `NNN` is the spec directory's number. It finds ids in test names in `test/` and `integration_test/`, and in `untested.md` next to the spec (lines `- <id>: <why it can't be tested automatically>`). It prints each missing id with its spec sentence and a final count. It exits 1 when a test or `untested.md` names an id that isn't in any spec, and with `--strict` also when any id is missing. In `scripts/check.sh`, run it after the tests on every `specs/*/` that has a `tasks.md`, with `--strict` for a spec whose `tasks.md` has no unticked task. Add `scripts/test-spec-coverage.sh` with fixture specs and tests, called from `check.sh`. List both in `CLAUDE.md` *Commands*.
- [X] T004 Add *Implementing a task* to `CLAUDE.md`: the loop in "How to do a task" above, then these stop rules. (1) The same check failing after three different fixes: stop and tell the user what was tried, rather than trying a fourth. (2) Never change a test's expectation, skip a test or loosen a check to get a task through. If a test looks wrong, quote the spec sentence that shows it, or ask. (3) A spec gap or a conflict between spec, plan and contracts: stop and ask (`/speckit-clarify`), rather than guessing. (4) Change only the files the task needs. Something else that's broken becomes a new task in `tasks.md`, not part of this one. (5) A reviewer `FAIL` that still stands after one round of fixes, or that conflicts with the spec: ask the user. (6) Start a fresh session for each phase in `tasks.md`; the ticked tasks carry the state.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Domain types, the repository interfaces, the SQLite store, and the scope and test helpers every screen uses. Nothing here is visible in the app yet.

**⚠️ CRITICAL**: No screen work can begin until this phase is complete

- [ ] T005 [P] Create `Pet` and `Species` in `lib/domain/pet.dart`, with tests in `test/domain/pet_test.dart`. `Pet` has `id` (String), `name`, `species`, `archived` (bool, `false` when added) and `createdAt` (UTC DateTime), value equality and `copyWith`. `Species` is an enum with ids `dog`, `cat`, `other` and labels Dog, Cat, Other, plus `Species.fromId`. Add `String validPetName(String name)`: name is "Required; trimmed; 1–40 characters", so it returns the trimmed name or throws `ArgumentError`. **Covers**: 001-FR-001.
- [ ] T006 [P] Create `EventType`, `DetailQuestion` and the match key in `lib/domain/event_type.dart`, with tests in `test/domain/event_type_test.dart`. `EventType` has `id`, `name`, `builtIn`, `questions` (List<DetailQuestion>, empty for custom types) and `removed` (custom only). `DetailQuestion` is a sealed class with `id` (unique within its type) and `label`, and two subclasses, as in data-model.md: `ChoiceQuestion` (`options`, a list of id and label; accepts an option id String; `describe` returns the option's label) and `DurationQuestion` (accepts whole seconds, an int ≥ 1; `describe` writes "2 min 30 s", "45 s" or "3 min"). Each has `bool accepts(Object answer)` and `String describe(Object answer)`, tested per kind. `String matchKey(String typed)` trims, collapses inner runs of spaces to one and lower-cases (research §7). `String validTypeName(String typed)` returns the name "as typed, trimmed and inner spaces collapsed; 1–40 characters" or throws `ArgumentError`. **Covers**: 001-EC-07.
- [ ] T007 Create the built-in types in `lib/domain/built_in_event_types.dart`, with tests in `test/domain/built_in_event_types_test.dart` (depends on T006). Define `builtInEventTypes`, in this order, with exactly the ids, names, questions and options in research §5: `vomiting` Vomiting (What came up: Food, Yellow liquid or bile, Foam, Hairball, Blood, Something else), `diarrhea` Diarrhea (Consistency: Soft, Watery; Blood seen: Yes, No), `seizure` Seizure (Kind: Focal, Grand mal; How long it lasted, duration), `coughing` Coughing (How long it lasted, duration), `sneezing` Sneezing, `limping` Limping (Which leg: Front left, Front right, Back left, Back right), `not_eating` Not eating (Meals missed: 1, 2, 3 or more), `lethargy` Lethargy, `scratching` Scratching, `accident` Accident in the house (What: Urine, Stool, Both), `wound` Wound. Tests check the order, that ids and match keys are unique, that question ids are unique within each type and option ids within each choice question. These checks also cover any question added to the list. **Covers**: 001-FR-002.
- [ ] T008 Create `MedicalEvent` in `lib/domain/medical_event.dart`, with tests in `test/domain/medical_event_test.dart` (depends on T006, T007). Fields: `id`, `petId`, `typeId`, `occurredAt` (UTC), `details` (Map<String, Object>), `note` (String?), `createdAt`, `updatedAt`, with value equality. Add `validDetails(EventType type, Map<String, Object> details)`: keys must be the type's question ids and each answer must pass its question's `accepts`; otherwise `ArgumentError`. Add `validNote(String? note)`: "trimmed, empty becomes null; up to 1000 characters". Add `detailsKeptFor(EventType newType, Map<String, Object> details)`, which keeps only the details whose question ids the new type also has (data-model, Event). **Covers**: 001-FR-006.
- [ ] T009 Create the repository interfaces in `lib/data/repositories.dart` exactly as in `contracts/repositories.md`: `PetRepository`, `EventTypeRepository`, `EventRepository`, the sealed `TypeChoice` with `ExistingType(typeId)` and `NewTypeName(name)`, and the `Clock` and `IdGenerator` typedefs. Give `ExistingType` and `NewTypeName` value equality, tested in `test/data/repositories_test.dart` (depends on T005, T006, T008).
- [ ] T010 [P] Create `lib/data/local/database.dart` with `Future<Database> openAppDatabase(DatabaseFactory factory, String path)`, which opens schema version 1 exactly as in data-model.md (`pets`, `event_types`, `events` with index `events_pet_time`, `settings`) and runs `PRAGMA foreign_keys = ON` in `onConfigure`. Change `openTestDatabase()` in `test/support/test_database.dart` to open through `openAppDatabase`. Tests in `test/data/local/database_test.dart`: the four tables and the index exist, an event with an unknown `pet_id` is refused, and `event_types.match_key` is unique.
- [ ] T011 Create `LocalPetRepository` in `lib/data/local/local_pet_repository.dart` implementing `PetRepository` (depends on T009, T010), taking the `Database`, a `Clock` and an `IdGenerator`. `watchActive` and `watchArchived` list by name; `watch(id)` emits null for an unknown id; `add` and `update` use `validPetName` and throw `ArgumentError` for a name that is empty after trimming or over 40 characters; `setArchived` flips the flag. Every stream emits on listen and again after each write. Tests in `test/data/local/local_pet_repository_test.dart` on the in-memory database, with a fixed clock and sequential ids. **Covers**: 001-FR-001, 001-US3-S2.
- [ ] T012 Create `LocalEventTypeRepository` in `lib/data/local/local_event_type_repository.dart` implementing `EventTypeRepository` (depends on T007, T009, T010). `static Future<LocalEventTypeRepository> open(Database db, IdGenerator ids)` loads the custom types into memory so `match` can answer synchronously. `watchOffered` emits the built-ins in their order, then custom types not removed, by name; `watchCustom` emits custom types not removed, by name; `byId` returns any built-in or custom type, removed or not, and throws `StateError` for an unknown id; `match(typed)` compares `matchKey` against built-ins first, then every custom type including removed ones, and returns null for a new name; `remove(customId)` sets `removed` and leaves events alone. Add `Future<String> resolveForSave(Transaction txn, TypeChoice choice)` for the event repository: an `ExistingType` returns its id; a `NewTypeName` that matches an existing type returns that type's id and sets `removed` back to `false` if it was removed; otherwise it inserts a custom type with a new id, keeping the caregiver's capitalization (`validTypeName`). After a transaction commits, `notifyChanged()` reloads the cache and re-emits. Tests in `test/data/local/local_event_type_repository_test.dart` cover each of these, including "vomiting" and "  Ear   SHAKING " matching existing types. **Covers**: 001-FR-004, 001-EC-04, 001-EC-07.
- [ ] T013 Create `LocalEventRepository` in `lib/data/local/local_event_repository.dart` implementing `EventRepository` (depends on T008, T011, T012), taking the `Database`, the `LocalEventTypeRepository`, a `Clock` and an `IdGenerator`. `watchForPet` lists newest first by `occurred_at`; `watch(id)` emits null once deleted. `log` writes, in one transaction, the event (with `createdAt` = `updatedAt` = now), any new or un-removed custom type through `resolveForSave`, and `settings.last_logged_pet_id`, then calls `notifyChanged()`. `update` writes the same fields and a new `updatedAt`, and leaves `last_logged_pet_id` alone. `log` and `update` throw `ArgumentError` when `occurredAt` is after the clock's now, the pet is archived (unless `update` keeps the event's current pet), a detail key isn't one of the type's questions, or a value doesn't fit its question (`validDetails`); the note goes through `validNote`. `details` is stored as a JSON object. `delete` removes the row. `lastLoggedPetId` reads the setting. Tests in `test/data/local/local_event_repository_test.dart` cover each rule, a failed write leaving nothing behind, two events seconds apart both kept, an event's moment read back as the same UTC instant, and an event still there after the database file (a temporary file, not in memory) is closed and opened again. **Covers**: 001-FR-003, 001-FR-012, 001-EC-01, 001-EC-02, 001-EC-03, 001-EC-06, 001-SC-004.
- [ ] T014 Create `AppScope` in `lib/ui/app_scope.dart`: an `InheritedWidget` holding a `PetRepository`, an `EventTypeRepository` and an `EventRepository`, with `AppScope.of(context)` (depends on T011–T013). Add the shared test helpers: `test/support/test_app.dart` with `Future<TestApp> openTestApp({DateTime? now})`, which opens the in-memory database, builds the three local repositories with a fixed clock (default 2026-11-14 12:00 local) and sequential ids, and has `Widget wrap(Widget child)` returning a `MaterialApp` inside the `AppScope`; and `test/support/screen_checks.dart` with `Future<void> expectAccessible(WidgetTester tester)`, which checks `androidTapTargetGuideline`, `iOSTapTargetGuideline`, `labeledTapTargetGuideline` and `textContrastGuideline`, then pumps at text scale 2.0 and expects no overflow (SC-002, research §11). Tests in `test/ui/app_scope_test.dart` (`of` finds the repositories; `updateShouldNotify` is true only when a repository changes) and `test/support/screen_checks_test.dart` (a small passing widget and a failing one for each check).

**Checkpoint**: The store and its rules are in place and tested; the app still shows the placeholder.

---

## Phase 3: User Story 3 - Set up pets, add and edit (Priority: P1)

**Goal**: The screens for adding and editing a pet. They ship with Story 1 in T024.

**Independent Test**: Widget tests: add a pet through the form and find it in `watchActive`; rename it and its events still belong to it.

Every screen task in Phases 3–7 calls `expectAccessible` in its screen's tests, and adds the steps it makes possible to `test/support/robot.dart` (`addPet`, `logEvent`, `openHistory`, …), which the journey tests drive.

- [ ] T015 [P] [US3] Create the pet form in `lib/ui/pets/pet_form_screen.dart` (`contracts/screens.md`, Pet form), with tests in `test/ui/pets/pet_form_screen_test.dart`. Adding: name field (max 40 characters), species choices from `Species` (labels from T005) and "Save", enabled once a name is entered; Save calls `PetRepository.add` and pops. Editing an existing pet fills the fields and Save calls `update`, keeping its id, so its events stay with it. Create `test/support/robot.dart` with `class Robot { Robot(this.tester); … }` and `addPet(name, species)`. **Covers**: 001-FR-001, 001-US3-S2.
- [ ] T016 [US3] Create the first pet screen in `lib/ui/pets/first_pet_screen.dart`, with tests in `test/ui/pets/first_pet_screen_test.dart` (depends on T015): the heading "Add your first pet" with the pet form's fields and "Save" (reuse the form's field widgets rather than copying them). Saving adds the pet; the screen doesn't navigate itself, because the app's start screen choice (T024) follows `watchActive`. **Covers**: 001-US3-S1.

---

## Phase 4: User Story 1 - Log an event as it happens (Priority: P1) 🎯 MVP

**Goal**: A caregiver opens the app, picks what happened and saves it for the right pet in two taps, with optional time, details and note, and can enter and later remove their own event types.

**Independent Test**: With one pet set up, log an event and confirm it appears with the right pet, event and time (spec, story 1).

- [ ] T017 [P] [US1] Create the "When" field in `lib/ui/common/date_time_field.dart`, with tests in `test/ui/common/date_time_field_test.dart`. It shows "Now" until changed; tapping opens the date picker with `lastDate` today, then the time picker; a time after the clock's now is not accepted. It takes a `Clock` so tests fix the time, and reports the chosen moment, or null for now. Times are shown in local time with `intl` `DateFormat`. **Covers**: 001-US1-S4, 001-FR-003.
- [ ] T018 [P] [US1] Create the duration field in `lib/ui/common/duration_field.dart`, with tests in `test/ui/common/duration_field_test.dart`: minutes and seconds number fields, reporting whole seconds ≥ 1, or null when both are empty or zero. **Covers**: 001-US1-S7.
- [ ] T019 [US1] Create the detail questions in `lib/ui/common/detail_questions.dart`, with tests in `test/ui/common/detail_questions_test.dart` (depends on T007, T018): for each of a type's questions, one exhaustive `switch` over the sealed `DetailQuestion` picks its input: a `ChoiceQuestion` is a row of choice chips (tapping the picked chip again clears it) and a `DurationQuestion` is the duration field. Every question is optional, and it reports a `Map<String, Object>` in the shape `validDetails` accepts. **Covers**: 001-US1-S7, 001-FR-006.
- [ ] T020 [P] [US1] Create the pet choices in `lib/ui/log/pet_choices.dart`, with tests in `test/ui/log/pet_choices_test.dart`: a row of choice chips for the given active pets, the picked one highlighted, and "Who is this for?" when none is picked. **Covers**: 001-FR-007.
- [ ] T021 [US1] Create the log sheet in `lib/ui/log/log_sheet.dart`, with tests in `test/ui/log/log_sheet_test.dart` (depends on T014, T017, T019, T020), following `contracts/screens.md`, Log sheet. Header: the type name and the pet; with several pets and none picked, the pet choices appear and "Save" stays disabled until one is chosen. Then "When", the type's detail questions, and "Note (optional)". "Save" is enabled as soon as a pet is picked and calls `EventRepository.log` with an `ExistingType` or `NewTypeName`; on success it closes and returns the saved event. A future time shows "That time is in the future" and the sheet stays open. Keep the fields in a widget the event screen (T033) can reuse, `lib/ui/common/event_fields.dart`, tested through the sheet. **Covers**: 001-US1-S3, 001-US1-S6, 001-FR-005, 001-EC-01.
- [ ] T022 [US1] Create the log screen and type grid in `lib/ui/log/log_screen.dart` and `lib/ui/log/type_grid.dart`, with tests in `test/ui/log/log_screen_test.dart` and `test/ui/log/type_grid_test.dart` (depends on T021). One active pet: its name as a heading, no picker. Several: the pet choices, with `lastLoggedPetId` picked if that pet is active and none picked otherwise; a new event's pet becomes the picked one. The grid shows large buttons for `watchOffered`, each opening the log sheet; after a save, the message "Saved: <type> for <pet>". Add `logEvent(type, {pet})` to the robot. Tests include Vomiting saved in two taps with the pet already picked, and one event logged for each of two pets. **Covers**: 001-US1-S1, 001-US1-S2, 001-US1-S3, 001-FR-002, 001-FR-007, 001-EC-05, 001-SC-001.
- [ ] T023 [US1] Add "Something else" in `lib/ui/log/something_else_sheet.dart`, with tests in `test/ui/log/something_else_sheet_test.dart`, and its button as the last one in the type grid (`lib/ui/log/type_grid.dart`) (depends on T022). It shows "What happened?"; continuing with typed text that `match`es an existing type uses that `ExistingType`, otherwise a `NewTypeName`, and opens the log sheet. Tests: "Ear shaking" saved and then offered in the grid; "ear SHAKING" saved as the existing "Ear shaking", with no second type created. **Covers**: 001-US1-S5, 001-FR-004, 001-EC-07.
- [ ] T024 [US1] Replace the placeholder with the app (depends on T016, T023). In `lib/app.dart`, `App` takes the three repositories, puts them in an `AppScope`, and shows the first pet screen while `watchActive` is empty and the log screen otherwise. In `lib/main.dart`, open the database with `openAppDatabase(databaseFactory, join(await getDatabasesPath(), 'pet_health_tracker.db'))`, build the local repositories with `DateTime.now` and `Uuid().v4`, and pass them to `App`; keep the Crashlytics setup. Rewrite `test/app_test.dart` for the start screen choice (no pets → "Add your first pet"; adding one → log screen; a pet exists → log screen). Add the US1 journey test, `test/journeys/us1_log_test.dart`, which runs the whole `App` through the robot: add Rex, log Vomiting now, log Seizure yesterday with a 2-minute duration, log "Ear shaking" in the caregiver's own words, and see each saved. Rewrite `integration_test/app_smoke_test.dart` to add a pet "Rex", tap Vomiting, Save and see "Saved: Vomiting for Rex" on a device, with no network or sign-in. Update `CLAUDE.md` *Project state* (the app is the medical event log from spec 001, stored on the phone in SQLite) and *Specs and design docs* (001 is being implemented: adding pets and logging events work). **Covers**: 001-US3-S1, 001-US1-S1, 001-FR-014.
- [ ] T025 [US1] Create "My event types" in `lib/ui/types/my_event_types_screen.dart`, with tests in `test/ui/types/my_event_types_screen_test.dart`, and add a menu to the log screen (`lib/ui/log/log_screen.dart`) with "My event types" (depends on T024). It lists `watchCustom`, each with "Remove", which calls `remove` with no further question; with none, "Types you type in yourself appear here". Tests: a removed type leaves the grid and its past events keep it; typing it again offers it again. **Covers**: 001-US1-S9, 001-FR-004, 001-EC-04.

**Checkpoint**: MVP. A caregiver can add pets and log events offline and signed out.

---

## Phase 5: User Story 2 - See how often events happen (Priority: P2)

**Goal**: Each pet's history, newest first, with the time since the previous event of the same type and, per type, the count, average time between and last time for the chosen period.

**Independent Test**: Log the same event for a pet several times at known times, then confirm the history shows the right gaps and frequency (spec, story 2).

- [ ] T026 [P] [US2] Create `lib/domain/frequency.dart`, with tests in `test/domain/frequency_test.dart` (research §8). `enum Period { last30Days, last90Days, last12Months, allTime }`, with `last90Days` the default and `DateTime? start(DateTime now)` (rolling windows ending now; 12 months is the same date and time one year back; all time has no start). `Duration? timeSincePrevious(MedicalEvent e, List<MedicalEvent> petEvents)`: the gap to the latest earlier event of the same type, null for the first. `List<TypeSummary> summaries(List<MedicalEvent> petEvents, Period p, DateTime now)`: per type with at least one event in the period, `count`, `averageGap` = (newest − oldest) ÷ (count − 1) when count ≥ 2, else null, and `lastAt`. Tests: one event shows no gap and no average, events on the period boundary, and each period. **Covers**: 001-FR-009, 001-FR-010, 001-US2-S2, 001-US2-S3, 001-US2-S4.
- [ ] T027 [P] [US2] Create `lib/domain/durations.dart`, with tests in `test/domain/durations_test.dart`: `String gapText(Duration d)` is "under an hour in minutes, under 2 days in hours, otherwise in days", and `String averageText(Duration d)` does the same, with "averages over 2 days get one decimal" (for example "3.5 days"). Singular and plural forms ("1 day", "2 days").
- [ ] T028 [US2] Create the event tile in `lib/ui/history/event_tile.dart`, with tests in `test/ui/history/event_tile_test.dart` (depends on T026, T027): the date and time in local time (`intl`), the type name, its answered details as "<question>: <answer>", the answer written by the question's `describe`, the note, and "<gap> since the previous one" when there is an earlier event of the same type. **Covers**: 001-FR-008, 001-US2-S2.
- [ ] T029 [US2] Create the summary in `lib/ui/history/type_summary.dart`, with tests in `test/ui/history/type_summary_test.dart` (depends on T026, T027): the period choice "30 days", "90 days" (default), "12 months", "All time", then one row per type in the period with its name, "<n> times", "about every <gap>" when the count is 2 or more, and "last <ago> ago"; with no events in the period, "Nothing logged in this period". **Covers**: 001-FR-010, 001-US2-S3, 001-US2-S4.
- [ ] T030 [US2] Create the pet history screen in `lib/ui/history/pet_history_screen.dart`, with tests in `test/ui/history/pet_history_screen_test.dart`, and add a "History" button to the log screen (`lib/ui/log/log_screen.dart`), disabled when no pet is picked (depends on T024, T028, T029). Title: the pet's name. The summary, then the pet's events newest first as event tiles (`watchForPet`; type names through `byId`, so removed types still show). An "Edit pet" action opens the pet form for this pet. Add `openHistory(pet)` to the robot. Add the US2 journey test, `test/journeys/us2_history_test.dart`: log Vomiting for Rex at three known times, open History, and see the events newest first, the gaps, "3 times" and the average, then switch periods and see the counts follow. **Covers**: 001-US2-S1, 001-FR-008, 001-US3-S2, 001-SC-003.

**Checkpoint**: Stories 1 and 2 and the first half of story 3 work.

---

## Phase 6: User Story 3 - Set up pets, list, archive and restore (Priority: P1)

**Goal**: A list of pets, and archiving and restoring a pet when it dies or is rehomed.

**Independent Test**: Archive a pet and confirm it isn't offered when logging and its history is still viewable from Archived pets; restore it and it is offered again (spec, story 3 scenarios 3–4).

- [ ] T031 [US3] Create the pets screen in `lib/ui/pets/pets_screen.dart`, with tests in `test/ui/pets/pets_screen_test.dart`, and add "Pets" to the log screen menu (`lib/ui/log/log_screen.dart`) (depends on T030): active pets by name, each opening its pet history, and "Add pet" opening the pet form. Test: adding a second pet makes the log screen show the pet choices, with the last-logged-for pet picked. **Covers**: 001-US1-S2.
- [ ] T032 [US3] Add archiving and restoring (depends on T031). In `lib/ui/history/pet_history_screen.dart`: "Archive" for an active pet, "Restore" for an archived pet, and "Archived" under the title of an archived pet. Create `lib/ui/pets/archived_pets_screen.dart` (archived pets by name, each opening its history; "No archived pets" when none), reached from "Archived pets" on the pets screen and from "See archived pets" on the first pet screen, shown only when archived pets exist (`lib/ui/pets/first_pet_screen.dart`). Tests in `test/ui/history/pet_history_screen_test.dart`, `test/ui/pets/archived_pets_screen_test.dart` and `test/ui/pets/first_pet_screen_test.dart`. Add the US3 journey test, `test/journeys/us3_pets_test.dart`: add Rex and Mia, log for Mia, archive Mia (only Rex offered, no picker), archive Rex ("Add your first pet" with "See archived pets"), restore Mia (offered again with her full history and picked as the last logged for). **Covers**: 001-US3-S3, 001-US3-S4, 001-FR-015, 001-EC-08, 001-EC-09.

**Checkpoint**: Story 3 complete.

---

## Phase 7: User Story 4 - Correct mistakes (Priority: P2)

**Goal**: Fix any part of a logged event, add details later, or delete it after confirming.

**Independent Test**: Edit an event's time and confirm the time between events updates; then delete an event and confirm it is gone (spec, story 4).

- [ ] T033 [US4] Create the event screen in `lib/ui/history/event_screen.dart`, with tests in `test/ui/history/event_screen_test.dart`, opened by tapping an event tile in the pet history (`lib/ui/history/pet_history_screen.dart`) (depends on T032). It reuses `lib/ui/common/event_fields.dart`, filled in: the pet (active pets, plus the event's own pet if archived), the type (`watchOffered` plus the event's own type), "When", the details and the note. "Save" calls `EventRepository.update`; changing the type keeps only the details its questions share (`detailsKeptFor`). Tests: adding details and a note later, and changing the pet, type and time, after which the history's gaps and summary follow. **Covers**: 001-US1-S8, 001-US4-S1, 001-FR-011.
- [ ] T034 [US4] Add "Delete" to the event screen (`lib/ui/history/event_screen.dart`) (depends on T033): it asks "Delete this event?" with "Delete" and "Cancel"; Delete calls `EventRepository.delete` and returns to the pet history. Tests in `test/ui/history/event_screen_test.dart`: Cancel keeps the event; Delete removes it from the list and from the summary counts. Add the US4 journey test, `test/journeys/us4_correct_test.dart`: log Vomiting twice, move the older one's time back a day and see the gap grow, then delete it and see the count drop to 1 with no gap. **Covers**: 001-US4-S2, 001-FR-011.

**Checkpoint**: All four stories work.

---

## Phase 8: Finish

- [ ] T035 Write `specs/001-medical-event-log/untested.md` for the ids a test can't check, each with its reason: `001-FR-013` (the app holds no feed, social features or diary entries, which a test can't prove absent) and `001-SC-002` (a first-time user logging without help needs a person; `expectAccessible` on every screen covers what can be checked). Tick this task, so `check.sh` runs `spec-coverage.sh --strict` on this spec and every other id must have a test. Update `CLAUDE.md` *Specs and design docs* to say spec 001 is implemented, with its plan and tasks in `specs/001-medical-event-log/`. The manual steps in `quickstart.md` are left for the user's own run on a phone.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: T001 first, merged so CI confirms the test database on Ubuntu; then T002 → T003 → T004, so every later task has the loop.
- **Foundational (Phase 2)**: depends on Phase 1; blocks every screen.
- **US3 add and edit (Phase 3)**: depends on Phase 2.
- **US1 (Phase 4)**: depends on Phase 2; T024 also needs T016. T024 is the first commit that changes what the app shows.
- **US2 (Phase 5)**: depends on T024 (the History button goes on the log screen); T026 and T027 can start right after Phase 2.
- **US3 archive (Phase 6)**: depends on T030, since archiving and restoring live on the pet history.
- **US4 (Phase 7)**: depends on T032 (the event screen offers the event's own archived pet) and T021 (shared fields).
- **Finish (Phase 8)**: after all stories.

### Task chain

```text
T001 → T002 → T003 → T004
T004 → T005, T006, T010 [P]
T006 → T007 → T008 → T009 (also needs T005)
T009 + T010 → T011 → T012 → T013 → T014
T014 → T015 → T016
T014 → T017, T018, T020 [P];  T018 → T019;  T017 + T019 + T020 → T021 → T022 → T023
T016 + T023 → T024 → T025
T005..T008 → T026, T027 [P] → T028, T029 → T030 (also needs T024)
T030 → T031 → T032 → T033 → T034 → T035
```

### Within each task

- The failing test comes first, then the code, in the same commit.
- Each new file in `lib/` gets its test in the same commit, or coverage (`scripts/coverage.sh`) fails.
- Files under 300 lines and functions under 40 (`tool/size_check.dart`): split widgets rather than adding baseline entries.

## Parallel Opportunities

Commits land one at a time on the branch, so "parallel" means tasks that don't depend on each other and could be done in either order, or by separate sessions in separate worktrees and rebased:

- Phase 2: T005, T006 and T010.
- Phase 4: T017, T018 and T020, once T014 is in.
- Across phases: T015 alongside T017–T020; T026 and T027 at any point after Phase 2.

## Parallel Example: User Story 1

```text
Task: "Create the 'When' field in lib/ui/common/date_time_field.dart" (T017)
Task: "Create the duration field in lib/ui/common/duration_field.dart" (T018)
Task: "Create the pet choices in lib/ui/log/pet_choices.dart" (T020)
```

## Parallel Example: User Story 2

```text
Task: "Create lib/domain/frequency.dart" (T026)
Task: "Create lib/domain/durations.dart" (T027)
```

---

## Implementation Strategy

### MVP first

1. Phase 1 (T001–T004): T001 merged to `main` so CI confirms the test database on Ubuntu, then the test command, spec coverage and the loop in `CLAUDE.md`.
2. Phase 2 (T005–T014).
3. Phases 3 and 4 (T015–T025): adding pets and logging events, wired into the app by T024.
4. **Stop and check**: `./scripts/spec-coverage.sh specs/001-medical-event-log` lists every US1 id as covered, and the US1 journey test passes.

### Then, in order

5. Phase 5 (US2): history and frequency.
6. Phase 6 (US3): pets list, archive and restore.
7. Phase 7 (US4): edit and delete.
8. Phase 8: `untested.md` and strict coverage. The feature is done when `check.sh` passes with every id covered or explained.

The feature merges to `main` at the end of each phase (constitution, Workflow 4), so the integration tests on `main` run on each phase's work. Deploys stay off for the rebuild period, so merging ships nothing to testers.
