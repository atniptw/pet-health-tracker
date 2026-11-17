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

## D-005 · Spec gap · T015: adding a pet starts with Dog picked

- **Question**: contracts/screens.md and tasks.md say the pet form's "Save" is enabled once a name is entered, but not which species is picked before the caregiver chooses one. With none picked, a name alone couldn't enable Save.
- **Options**: (a) the first species, Dog, picked; (b) none picked, and Save waits for a species too; (c) Other picked.
- **Chose**: (a): "enabled once a name is entered" points to a species already picked, and Dog is first in research §6's list. A cat owner taps "Cat" before Save.
- **Changed**: contracts/screens.md, Pet form; `PetForm` in `lib/ui/pets/pet_form.dart` (shared by `lib/ui/pets/pet_form_screen.dart` and `lib/ui/pets/first_pet_screen.dart`); the species choices test in `test/ui/pets/pet_form_screen_test.dart`
- **To undo**: start `_species` as null in `_PetFormState`, require it for Save, and change that test and the contracts line.
- **Status**: open

## D-006 · Contract gap · T016: after saving the first pet, the screen keeps its fields with Save disabled

- **Question**: contracts/screens.md shows First pet going to Log once saved, and tasks.md says the screen doesn't navigate itself because the start screen choice (T024) follows `watchActive`. Neither says what the screen shows between the save and that replacement: cleared fields with Save enabled would let a second tap add a second pet.
- **Options**: (a) keep the entered name and species, with Save disabled; (b) clear the fields, with Save disabled until a name is typed again; (c) keep the fields with Save enabled again.
- **Chose**: (a): the pet is saved, so nothing on the screen invites saving it again, and the screen shows what was saved until the start screen choice replaces it. The pet form shares this, which it never shows since it closes once saved.
- **Changed**: contracts/screens.md, First pet; `PetForm` in `lib/ui/pets/pet_form.dart`, shared by `lib/ui/pets/first_pet_screen.dart` and `lib/ui/pets/pet_form_screen.dart`; the save test in `test/ui/pets/first_pet_screen_test.dart`
- **To undo**: reset `_saving` (and clear `_name` for (b)) after a successful save in `_PetFormState._save`, and change that test and the contracts line.
- **Status**: open

## D-007 · Contract gap · T017: a picked time after now keeps the field as it was and shows "That time is in the future"

- **Question**: contracts/screens.md says the "When" pickers "stop at now", and tasks.md that a time after the clock's now is not accepted. The date picker can stop at today, but Flutter's time picker has no latest time, so a later hour today can still be picked. Neither says what the field shows then. FR-003 also allows "any earlier date", but the date picker needs an earliest one.
- **Options**: (a) keep the previous value and show "That time is in the future", the log sheet's wording, under the field until the next pick; (b) keep the previous value silently; (c) set the time to now.
- **Chose**: (a): the caregiver sees why the pick didn't take, in the words the sheet already uses, and the field never holds a future time. The date picker starts at 1 January 1900, earlier than any pet's events.
- **Changed**: contracts/screens.md, Log sheet; quickstart.md, step 6; research.md §4, Validation; `DateTimeField` in `lib/ui/common/date_time_field.dart`; the future time tests in `test/ui/common/date_time_field_test.dart`
- **To undo**: drop `_pickedInFuture` and the `errorText` in `_DateTimeFieldState`, and change those tests, the contracts line, quickstart.md step 6 and research.md §4.
- **Status**: open

## D-008 · Contract gap · T018: the duration fields are "Minutes" and "Seconds", up to 3 and 2 digits, added up as typed

- **Question**: contracts/screens.md asks for "minutes and seconds fields" and tasks.md for whole seconds ≥ 1, but neither names the fields, says how many digits they take, or what seconds over 59 mean.
- **Options**: (a) "Minutes" (up to 3 digits) and "Seconds" (up to 2 digits), digits only, with seconds over 59 added as they are (0 and 90 is 90 seconds); (b) the same, with seconds over 59 refused; (c) one field of seconds.
- **Chose**: (a): the contract's own words as the labels, and nothing typed is refused or rewritten, which is the least to explain to a caregiver timing a seizure. 999 minutes is well past any seizure or coughing fit, and the limits keep the total a small whole number.
- **Changed**: contracts/screens.md, Log sheet; `DurationField` in `lib/ui/common/duration_field.dart`; the tests in `test/ui/common/duration_field_test.dart`
- **To undo**: change the labels, the `LengthLimitingTextInputFormatter`s or add a seconds limit in `_DurationFieldState`, and those tests and the contracts line.
- **Status**: open

## D-009 · Choice · T020: tapping the picked pet again keeps it picked

- **Question**: The pet choices are choice chips, and the detail question chips clear when the picked one is tapped again. FR-007 says the picked pet is "clearly shown and changeable", but not whether tapping it again clears it.
- **Options**: (a) tapping the picked pet keeps it picked; (b) it clears the pick, as the detail question chips do.
- **Chose**: (a): a cleared pet would only disable "Save" on the log sheet, and FR-007 asks for a pet that can be changed, not removed.
- **Changed**: contracts/screens.md, Log screen; `PetChoices` in `lib/ui/log/pet_choices.dart`; the test "tapping the picked pet again keeps it picked" in `test/ui/log/pet_choices_test.dart`
- **To undo**: make `onPicked` a `ValueChanged<String?>` and pass null when the picked chip is tapped again, and change that test and the contracts line.
- **Status**: open

## D-010 · Contract gap · T021: once the log sheet shows the pet choices, they stay after a pet is picked

- **Question**: contracts/screens.md says that with several pets and none picked, the pet choices appear in the log sheet's header and "Save" stays disabled until one is chosen. It doesn't say whether the choices give way to the picked pet's name once one is chosen, which would leave a mis-tapped pet unchangeable in the sheet.
- **Options**: (a) the choices stay for the sheet's life, with the chosen pet highlighted; (b) they give way to the pet's name, as when a pet was already picked.
- **Chose**: (a): FR-007 asks for a picked pet that is "clearly shown and changeable", and the highlighted chip shows it as clearly as the name would.
- **Changed**: contracts/screens.md, Log sheet; `_LogSheetState` in `lib/ui/log/log_sheet.dart`; the test "once chosen in the sheet, the pet choices stay and can change (D-010)" in `test/ui/log/log_sheet_test.dart`
- **To undo**: show the pet's name in `_LogSheetState._header` once `_isActive(_petId)` is true instead of keeping `_choosingPet` fixed, and change that test and the contracts line.
- **Status**: open

## D-011 · Contract gap · T021: a time found to be in the future on saving shows its message under "When"

- **Question**: contracts/screens.md and research.md §4 say saving a time after now shows "That time is in the future" and the sheet stays open, but not where the message shows or when it goes away.
- **Options**: (a) under "When", as the field shows it for a future pick (D-007), until another time is picked; (b) a snack bar; (c) a line above "Save".
- **Chose**: (a): the message sits on the field the caregiver has to change, in the same place and words as D-007.
- **Changed**: contracts/screens.md, Log sheet; research.md §4, Validation; `DateTimeField` (its `errorText`) in `lib/ui/common/date_time_field.dart`, `EventFields` (its `whenError`) in `lib/ui/common/event_fields.dart` and `_LogSheetState` in `lib/ui/log/log_sheet.dart`; the future time tests in `test/ui/log/log_sheet_test.dart`
- **To undo**: drop `DateTimeField.errorText` and `EventFields.whenError`, show the message elsewhere from `_LogSheetState._save`, and change those tests, the contracts line and research.md §4.
- **Status**: open

## D-012 · Choice · T021: the note stops taking characters at 1000

- **Question**: data-model.md allows a note of up to 1000 characters, and `validNote` refuses a longer one, but neither says what the note field does as the caregiver nears the limit.
- **Options**: (a) the field stops taking characters at 1000, with no counter; (b) a "0/1000" counter under the field; (c) an error on saving.
- **Chose**: (a): a note that long is rare, and a counter would show on every log for it.
- **Changed**: contracts/screens.md, Log sheet; `EventFields` in `lib/ui/common/event_fields.dart`; the test "the note takes up to 1000 characters" in `test/ui/log/log_sheet_test.dart`
- **To undo**: replace the `LengthLimitingTextInputFormatter` in `EventFields.build` with `maxLength: 1000`, and change that test and the contracts line.
- **Status**: open

## D-013 · Choice · T022: a new "Saved" message replaces the one before it at once

- **Question**: contracts/screens.md shows "Saved: <type> for <pet>" after each save, but not what happens when a second event is saved while the first message still shows, as when the same thing is logged for two pets (EC-05).
- **Options**: (a) the new message replaces the earlier one at once; (b) it waits in line until the earlier one has gone, a few seconds later.
- **Chose**: (a): the message on screen is always about the event just saved, so the caregiver logging for a second pet sees that pet's name straight away.
- **Changed**: contracts/screens.md, Log (home screen); `_LogScreenState._log` in `lib/ui/log/log_screen.dart`; the test "a new "Saved" message replaces the one before it (D-013)" in `test/ui/log/log_screen_test.dart`
- **To undo**: drop `removeCurrentSnackBar()` in `_LogScreenState._log`, and change that test, the "Saved: Vomiting for Mia" check in the 001-EC-05 test and the contracts line.
- **Status**: open

## D-014 · Contract gap · T023: "What happened?" takes up to 40 characters, and "Continue" waits for a name

- **Question**: contracts/screens.md says "Something else" first shows a text field "What happened?", but not how the caregiver moves on to the log sheet, what happens with nothing typed, or what the field does past the 40 characters a type name may have (data-model.md, `validTypeName`).
- **Options**: (a) a "Continue" button, disabled while the field is empty or only spaces, with the keyboard's done key doing the same, and the field stopping at 40 characters; (b) the same with an error message under the field instead of a disabled button; (c) a "0/40" counter.
- **Chose**: (a): the same pattern as "Save" on the first pet screen and the note's limit (D-012), with nothing to read or fix.
- **Changed**: contracts/screens.md, Log sheet; quickstart.md, steps 7, 8 and 19; `SomethingElseSheet` in `lib/ui/log/something_else_sheet.dart`; the tests "\"Continue\" is disabled while \"What happened?\" is empty or only spaces (D-014)", "\"What happened?\" takes up to 40 characters (D-014)" and the done key tests in `test/ui/log/something_else_sheet_test.dart`
- **To undo**: change `_SomethingElseSheetState` (its `_hasName` check, `onSubmitted` and the `LengthLimitingTextInputFormatter`), and those tests, the contracts line and quickstart.md steps 7, 8 and 19.
- **Status**: open

## D-015 · Choice · T023: "Something else" is an outlined button

- **Question**: contracts/screens.md makes "Something else" the last button in the type grid, but not whether it looks like the type buttons.
- **Options**: (a) the same size as the type buttons, outlined rather than filled; (b) the same as a type button.
- **Chose**: (a): it opens a question rather than logging a type, and the outline sets it apart while keeping it as large as the rest.
- **Changed**: contracts/screens.md, Log (home screen); `TypeGrid` in `lib/ui/log/type_grid.dart`; the test "\"Something else\" comes after the types and reports its tap" in `test/ui/log/type_grid_test.dart`; `Robot.logSomethingElse` in `test/support/robot.dart`
- **To undo**: make the "Something else" button a `FilledButton.tonal` in `TypeGrid.build`, and change the finders in those tests, `test/ui/log/something_else_sheet_test.dart`, `Robot.logSomethingElse` and the contracts line.
- **Status**: open

## D-016 · Conflict · T023: a typed name matching a removed custom type is logged by name, which un-removes it

- **Question**: T023 in tasks.md said a typed name that `match`es an existing type uses that `ExistingType`. But FR-004 says a removed type entered again "MUST offer it again", research §7 says a match "un-removes it if it was removed", and data-model.md says a typed name matching a removed custom type sets `removed` back to false. The event type repository only un-removes a type for a `NewTypeName`, so an `ExistingType` for a removed type would leave it out of the grid.
- **Options**: (a) follow the spec, research and data model: a match to a removed custom type is logged as a `NewTypeName` of that type's name; (b) follow the task text and log it as `ExistingType`, leaving it removed.
- **Chose**: (a), the spec. The task text is changed to match.
- **Changed**: tasks.md, T023; `logSheetFor` in `lib/ui/log/something_else_sheet.dart`; the test "001-FR-004: a removed type typed again is offered again" in `test/ui/log/something_else_sheet_test.dart`
- **To undo**: in `logSheetFor`, use `LogSheet.forType` for every match (drop the `type.removed` case), and change that test and the T023 text.
- **Status**: open

## D-017 · Choice · T024: a failed read of the pets at start says so

- **Question**: The spec and contracts choose the start screen from the active pets, but don't say what shows when they can't be read. After a list has been read, keeping the screen shown (and the log screen's pick) is the least for the user. Before any has been read, something has to show.
- **Options**: (a) a blank screen; (b) a message, "Your pets couldn't be loaded. Close the app and open it again."; (c) the message with a "Try again" button; (d) the first pet screen.
- **Chose**: (b). A blank screen leaves the caregiver with no way to tell what's wrong, and the first pet screen would make them add pets they already have. A "Try again" button adds more than the spec asks for. The error is reported to the app's error handler (Crashlytics in release builds) without the read's own message, which can hold a pet's name.
- **Changed**: contracts/screens.md, App start; `App.loadFailed` and `_StartScreen` in `lib/app.dart`; the tests under "when reading the active pets fails" in `test/app_test.dart`
- **To undo**: show a blank `Scaffold` for the failed case in `_StartScreen.build`, drop `App.loadFailed`, and change the test "before any list, says the pets couldn't be loaded (D-017)…" and the contracts line.
- **Status**: open

## D-018 · Choice · T025: a failed read of the custom types says so

- **Question**: The contracts list the custom types on My event types, but don't say what shows when they can't be read, or when removing one fails.
- **Options**: (a) a blank screen; (b) as for the pets at start (D-017): keep a list already read, and before any, "Your event types couldn't be loaded. Close the app and open it again."; (c) the message with a "Try again" button. For a failed remove: (d) report it and enable "Remove" again; (e) also show a message.
- **Chose**: (b) and (d). They match how the start screen and the log sheet already handle failures, and add nothing the spec doesn't ask for. Errors go to the app's error handler (Crashlytics in release builds) without the read's or write's own message, which can hold a type's name.
- **Changed**: contracts/screens.md, My event types; `MyEventTypesScreen` in `lib/ui/types/my_event_types_screen.dart`; the tests "a failed read before any list says the types couldn't be loaded (D-018)…", "a failed read after a list keeps the list shown (D-018)" and "when removing fails, \"Remove\" works again…" in `test/ui/types/my_event_types_screen_test.dart`
- **To undo**: show nothing for the failed case in `_MyEventTypesScreenState.build`, drop `MyEventTypesScreen.loadFailed`, and change those tests and the contracts lines.
- **Status**: open

## D-019 · New task · T036: an open log sheet saves through the repositories it was opened with

- **Question**: The security review of T023 found that `LogSheet._save` writes through `AppScope.of(context).events` as it is when "Save" is tapped. If `AppScope` were given other repositories while the sheet is open, an event for a pet from the first ones would be saved into the others. Nothing in spec 001 swaps the repositories while the app runs, so this can't happen yet, but the log screen and "Something else" already guard against it, and the sheet doesn't.
- **Options**: (a) a new task that makes the sheet save through the repository it opened with and close without saving when the repositories have changed; (b) leave it until a feature swaps repositories.
- **Chose**: (a), as T036 in Phase 8, under stop rule 4: the code is from T021, so it isn't part of T023.
- **Changed**: tasks.md, T036
- **To undo**: remove T036 from tasks.md.
- **Status**: open

## D-020 · New task · T037: the log screen keeps its pets and types when a read fails

- **Question**: The lifecycle review of T024 found that the log screen shows `pets.data ?? const []`, so a failed `watchActive` read empties its pet list until the next good read, and a failed `watchOffered` read empties the grid. The start screen (D-017) and My event types (D-018) keep the last list and report the failure; the log screen doesn't.
- **Options**: (a) a new task that keeps the last pets and types and reports the failure, as D-017 and D-018 do; (b) leave it.
- **Chose**: (a), as T037 in Phase 8, under stop rule 4: the code is from T022, so it isn't part of T024.
- **Changed**: tasks.md, T037
- **To undo**: remove T037 from tasks.md.
- **Status**: open

## D-021 · Spec gap · T026: the summary lists the most recently happened type first

- **Question**: The spec and contracts give one summary row per type in the period, but not their order.
- **Options**: (a) the type whose newest event happened most recently first, as the events below are newest first; (b) by type name; (c) by count.
- **Chose**: (a): it matches the newest-first history (story 2 scenario 1), and the type that just happened again is what the caregiver is likely checking.
- **Changed**: spec.md, Clarifications; `summaries` in `lib/domain/frequency.dart`; the test "001-US2-S3: per type, the count, the average time between and the last one, over the period" in `test/domain/frequency_test.dart`
- **To undo**: sort the result of `summaries` the other way, and change that test and the Clarifications line.
- **Status**: open

## D-022 · Spec gap · T027: durations are rounded down, under a minute is "0 minutes", averages keep ".0"

- **Question**: research.md §8 shows durations "under an hour in minutes, under 2 days in hours, otherwise in days", and "averages over 2 days get one decimal (for example "every 3.5 days")", but doesn't say how they are rounded, what a gap under a minute shows, or whether a whole-number average shows "3.0 days" or "3 days".
- **Options**: rounding: (a) down, (b) to the nearest; under a minute: (a) "0 minutes", (b) a separate wording such as "under a minute"; whole-number averages: (a) "3.0 days", (b) "3 days".
- **Chose**: (a) for each. Rounding down keeps every figure within its unit (59 minutes 59 seconds is "59 minutes", not "60 minutes"; just under 2 days is "47 hours") and never overstates a gap. "0 minutes" follows "in minutes" without adding wording. "One decimal" keeps the decimal on a whole number, so averages over 2 days all read the same way. From exactly 2 days on, an average is in days with one decimal ("2.0 days").
- **Changed**: spec.md, Clarifications; research.md §8, Showing durations; `gapText` and `averageText` in `lib/domain/durations.dart`; `test/domain/durations_test.dart`
- **To undo**: change the rounding in `gapText` and `averageText`, and those tests and the Clarifications line.
- **Status**: open

## D-023 · Contract gap · T028: an event tile shows the type first, then the date and time, details in question order, note, gap

- **Question**: contracts/screens.md lists what each event in Pet history shows (date and time, type, its answered details, note, gap) but not their order on the tile, or the order of the details.
- **Options**: (a) the type name as the tile's title, then the date and time, each answered detail in the type's question order, the note, and the gap; (b) the date and time as the title, then the type; (c) details in the order they were answered.
- **Chose**: (a): the type name is what a caregiver scans for, the date and time sit right under it, and the details read in the same order the log sheet asks them. The order answers were given isn't stored. The date and time are written as "When" shows them on the log sheet ("Nov 13, 2026 9:30 PM").
- **Changed**: contracts/screens.md, Pet history; `EventTile` in `lib/ui/history/event_tile.dart`; `dateTimeText` in `lib/ui/common/date_time_field.dart`; `test/ui/history/event_tile_test.dart`
- **To undo**: reorder the children of `EventTile`, and change those tests.
- **Status**: open
