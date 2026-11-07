# Feature Specification: Multi-pet symptom logging

**Status**: Shipped | **Created**: 2026-10-06

## Overview
A redesigned home screen and a "Log a symptom" bottom sheet for `atniptw/pet-health-tracker` (Flutter, iOS + Android). The goal is the fewest taps from opening the app to a saved log. There is one primary button, "Log a symptom". It opens a sheet where the user picks a pet and a symptom. **Picking a symptom saves the log straight away**, timed now. The catalog questions are optional follow-up.

There are two layouts for households with 3 or more pets:
- **2a**: 4 pets. Pet cards in a 2×2 grid on home; the sheet's pet picker is a 2×2 grid of pills.
- **2b**: 6 or more pets. A row of pet avatars that scrolls sideways, on home and in the sheet. The pet last logged for is selected by default.

Recommendation: build one adaptive layout. Use 2a for 4 pets or fewer and 2b for more than 4.

## Fidelity
**High fidelity** for layout, spacing, type and colour. The screens are static mockups, so the interactions below are specified in this spec, not shown in the file.

## Screens
### Home (2a: ≤4 pets)
- App bar 60px tall: household name (`Household.name`) in 22/600, left padding 20. Settings icon button on the right, 44×44, icon 24px, `mute` colour. It opens the existing `SettingsScreen`.
- Pet grid: 2 columns, gap 10, horizontal padding 16, top padding 4. Each card is `surf` with a 1px `line` border, radius 20 and padding 12. It contains a row (gap 10) of:
  - an avatar circle, 36px, initial in 15/700;
  - the name in 15/600;
  - the meta line in 12/400 `mute`: `"{species} · {breed}"` (same format as `_PetTile`).
  - Tapping a card opens `PetLogsScreen`.
- "RECENT" list across all pets: section padding 22 top and 20 sides. The label is 12/600, letter-spacing .06em, uppercase, `mute`. Each row has 10px vertical padding and a 1px `line` divider (none on the last row) and contains:
  - a 28px pet avatar (12/700 initial);
  - the title in 15/600 (catalog label, or the `title` for `other` logs);
  - a summary in 13 `mute`: catalog answers joined with " · ", or a day label for `other` logs;
  - the time on the right in IBM Plex Mono 12 `mute`.
- Primary button: fixed 16px from the left and right edges and 26px above the bottom safe area. It is 60px tall, radius 30, `acc` background, white 17/600 label "Log a symptom" with a 24px `add` icon (gap 8). Shadow: `0 6 18 rgba(acc, .35)`.

### Home (2b: >4 pets)
Same as 2a, except the grid is replaced by a row of avatars that scrolls sideways:
- Padding 6/20/4, gap 14. Each item is 56px wide: a 56px circle with a 20/700 initial, and the name below it in 13/600 (gap 6).
- The "Recent" header gets an "All pets" link on the right (13/600, `accText`).

### Log sheet (modal bottom sheet)
- Scrim `rgba(20,16,12,.38)`. The sheet is `surf`, top radius 28, padding 8 top and 30 bottom, with gap 14 between sections. Drag handle 32×4, radius 2, `line` colour.
- **Who** (label 13/600 `mute`):
  - **2a:** a 2-column grid of pills (gap 8) with 16px side padding. Each pill is 48px tall, radius 24, 1px `line` border, padding 0 12 0 6, with a 34px avatar and the name in 15/600.
    - Selected pill: `accSoft` fill, 2px `acc` border, `accText` text, and the avatar becomes an `acc` circle with a white `check` icon.
  - **2b:** a row of 56px avatars that scrolls sideways, gap 12, padding 0 20. The selected avatar has an `acc` fill, white initial, and a double ring (`0 0 0 3px surf, 0 0 0 5px acc`). Its name is 13/700 `accText`. Label: "Who · last logged for {pet}". The selected pet is moved to the front of the row.
- **What happened** (padding 0 20): 52–54px rows separated by 1px `line` dividers. Each row is gap 14: a 12px coloured dot, the label in 16/600, and a `chevron_right` icon (22px, `mute`). Rows in order:
  - Seizure
  - Vomit
  - Diarrhea
  - "Something else…", which uses an `edit` icon instead of a dot.
- **Logged before for {pet}** (2a): chips with the most recent distinct `other` titles for the selected pet. Each chip is 34px tall, radius 17, 1px `line` border, 14/500. Tapping one logs that title straight away.
- Footnote (2b): "Picking a symptom saves it right away, timed now." 12px `mute`.

### Details screen (after a symptom is picked)
See **1b**, screen 3 (Seizure). This screen opens after the log is already saved.
- Header: `close` icon, the title "{Symptom}", subtitle "{Pet} · saved {time}", and a Done pill.
- One question control per catalog question:
  - yes/no → switch rows
  - single choice → segmented button or chips
  - number → a number field, labelled with the question's `unit` when it has one (e.g. seconds).
- "Add a note" field.
- Every change is written as an update to the saved log.

## Interactions & behaviour
1. Tap "Log a symptom" → the sheet opens with the last-logged pet selected. Store that pet's id per user, e.g. in local prefs. If there is only 1 pet, hide the "Who" section.
2. Tap a pet → it becomes selected. The "Logged before" chips update to that pet.
3. Tap a catalog symptom:
   - It creates a `SymptomLog` with `symptom: key`, `occurredAt: now`, `createdBy: uid` and `answers: {}`.
   - The write is not awaited, the same as the current `LogSymptomScreen._save`, so logging works offline.
   - The sheet closes and the details screen opens.
4. Tap "Something else…":
   - It opens a title field: autofocused, max 100 characters, sentence capitalisation, matching the current form.
   - Saving creates an `other` log.
5. Tap a "Logged before" chip → creates an `other` log with that title. Show a snackbar: "{title} logged for {pet}" with an Undo action (hard-delete the log).
6. Details screen:
   - Answers are written via an update that touches only the changed `answers` fields (see data-model.md: "Edits keep unknown answers").
   - A yes/no answer is stored only when true.
   - "Done" or close → pop.
7. Errors: if the save fails, show the existing snackbar: "Couldn't save the log: $e".

## Decisions
Answers to questions the handoff left open. Where these differ from the rest of this spec or the plan, these win.

1. **"All pets" link:** opens a list of every pet. Tapping a pet opens its history, and admins can add a pet from it.
2. **Dark-mode colours:** the avatar and symptom-dot colours are derived from the dark palette. Avatars get a dark, muted fill with a light initial, as `accSoft`/`accText` do. Dots are lightened so they show on the dark background.
3. **"Something else…":** the title field opens inside the sheet, in place of the symptom list, with Save and Back. Saving closes the sheet and shows the same "{title} logged for {pet}" snackbar with Undo as the chips. The details screen doesn't open; a note can be added later from the pet's history.
4. **No pets yet:** admins see a centred "Add your first pet" button. Other members see "No pets yet. Ask a household admin to add one." The "Log a symptom" button is hidden until there is a pet.
5. **Old logging paths:** the "Log symptom" button on a pet's history is removed. The full-screen `other` form stays, for editing an existing log only.
6. **Chips and footnote:** both layouts show the "Logged before" chips. Neither shows the footnote.
7. **Recent list:** 5 rows. Times from today show as `14:05`, yesterday as `Yesterday`, older ones as `Mon 3 Oct`.
8. **Changing the time:** the details screen has an "Occurred {time}" row at the top. Tapping it opens the same date and time picker as the `other` form, and saving writes only `occurredAt`.
9. **Last-logged pet:** the pet of the user's own most recent log, read from Firestore, not local prefs, so it is the same on every device.
10. **No stopwatch:** number questions get a number field labelled with the question's `unit`, not a stopwatch.
