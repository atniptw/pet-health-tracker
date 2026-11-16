# Decisions: Medical Event Log

Choices made in autonomous runs, for review (`docs/dev-workflow/autonomous-runs.md`).

## D-001 · Choice · T005, T006, T008: name and note lengths count user-perceived characters

- **Question**: data-model.md limits a pet name and a custom event type name to "1–40 characters", and an event's note to "up to 1000 characters", but doesn't say what a character is. An emoji or an accented letter can be several UTF-16 code units.
- **Options**: (a) user-perceived characters (grapheme clusters), as a Flutter text field counts toward its limit; (b) UTF-16 code units (`String.length`); (c) Unicode code points.
- **Chose**: (a), so the limit matches what the caregiver sees and what the name and note fields will allow. This adds `characters` 1.4.x as a direct dependency (it was already in the build through Flutter), since `lib/domain/` has no Flutter imports (plan.md).
- **Changed**: plan.md, Primary Dependencies; pubspec.yaml
- **To undo**: count `name.length` in `checkedNameLength` (`lib/domain/names.dart`), which `validPetName` and `validTypeName` share, and `trimmed.length` in `validNote` (`lib/domain/medical_event.dart`), change the emoji tests in `test/domain/pet_test.dart`, `test/domain/event_type_test.dart` and `test/domain/medical_event_test.dart`, and drop `characters` from pubspec.yaml and plan.md.
- **Status**: open

## D-002 · Spec gap · T007: ids of the built-in detail questions and options

- **Question**: research.md §5 lists each built-in type's questions and options by label, and says their ids never change, but doesn't give the ids. They are stored in every event's `details`, so they are fixed from the first release.
- **Options**: (a) short snake_case ids from the labels, reusing data-model.md's examples `kind` and `duration`; (b) the labels themselves; (c) numbered ids (`q1`, `o1`).
- **Chose**: (a). Questions: `what_came_up`, `consistency`, `blood_seen`, `kind`, `duration` (both "How long it lasted"), `leg`, `meals_missed`, `what`. Options are the label in snake_case, except Yellow liquid or bile → `bile`, and Meals missed 1, 2, 3 or more → `one`, `two`, `three_or_more`. Labels can change without touching stored events.
- **Changed**: `lib/domain/built_in_event_types.dart`, `test/domain/built_in_event_types_test.dart`
- **To undo**: change the ids in both files before any event is stored with them.
- **Status**: open

## D-003 · Spec gap · T011, T012: pets and custom event types listed by name ignoring case, same names by id

- **Question**: data-model.md and contracts/repositories.md list active and archived pets, and the custom event types, "by name", but don't say whether case counts or how pets with the same name are ordered. A plain string or SQLite sort puts "Ziggy" before "apple", and Dart's sort isn't stable, so two pets called "Max" could swap places between emits.
- **Options**: (a) by `toLowerCase()` of the name, then by `id`; (b) SQLite `COLLATE NOCASE`, which folds only ASCII letters; (c) case-sensitive code-unit order; (d) locale-aware collation, which needs a new dependency.
- **Chose**: (a). Research §7 already compares type names with `toLowerCase()`, so names are compared the same way throughout, and the `id` tie-break keeps the same order on every emit. Accented letters sort after "z", as in (b) and (c).
- **Changed**: data-model.md, Pet and EventType; `byName` in `lib/domain/names.dart`, used by `lib/data/local/local_pet_repository.dart` and `lib/data/local/local_event_type_repository.dart`; `test/data/local/local_pet_repository_test.dart`, `test/data/local/local_event_type_repository_test.dart`
- **To undo**: change `byName` in `lib/domain/names.dart`, which both repositories share, the pet list-order tests, the custom type list-order test in `test/data/local/local_event_type_repository_test.dart`, and the two data-model.md sentences. Custom type names are unique by their lower-cased match key, so the `id` tie-break never applies to them.
- **Status**: open

## D-004 · Spec gap · T013: events at the same moment listed most recently logged first, then by id

- **Question**: data-model.md and contracts/repositories.md list a pet's events "newest first", by `occurred_at`, but don't say how events at the same moment are ordered. Two events back-dated to the same minute are equal there, and SQLite returns equal rows in no set order, so they could swap places between emits of the history.
- **Options**: (a) by `created_at` descending, then `id` descending; (b) by `id` only; (c) leave the order of equal moments to SQLite.
- **Chose**: (a): the one logged later shows above, as it would for events a moment apart, and the `id` tie-break keeps the same order on every emit.
- **Changed**: data-model.md, Event; `watchForPet` in `lib/data/local/local_event_repository.dart`; the two same-moment tests in `test/data/local/local_event_repository_test.dart`
- **To undo**: change the `orderBy` in `watchForPet`, those tests and the data-model.md sentence.
- **Status**: open
