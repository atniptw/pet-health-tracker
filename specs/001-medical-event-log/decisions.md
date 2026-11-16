# Decisions: Medical Event Log

Choices made in autonomous runs, for review (`docs/dev-workflow/autonomous-runs.md`).

## D-001 · Choice · T005: name lengths count user-perceived characters

- **Question**: data-model.md limits a pet name to "1–40 characters" but doesn't say what a character is. An emoji or an accented letter can be several UTF-16 code units.
- **Options**: (a) user-perceived characters (grapheme clusters), as a Flutter text field counts toward its limit; (b) UTF-16 code units (`String.length`); (c) Unicode code points.
- **Chose**: (a), so the limit matches what the caregiver sees and what the name field will allow. This adds `characters` 1.4.x as a direct dependency (it was already in the build through Flutter), since `lib/domain/` has no Flutter imports (plan.md).
- **Changed**: plan.md, Primary Dependencies; pubspec.yaml
- **To undo**: count `trimmed.length` in `validPetName` (`lib/domain/pet.dart`), change its emoji test, and drop `characters` from pubspec.yaml and plan.md.
- **Status**: open
