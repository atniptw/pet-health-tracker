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

