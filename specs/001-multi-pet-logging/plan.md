# Implementation Plan: Multi-pet symptom logging

**Spec**: [spec.md](spec.md)

## About the design files
`Pet Health Tracker.dc.html` is a **design reference made in HTML**, not production code. Recreate it in the existing Flutter app (`lib/features/...`), using Riverpod and the repo's patterns. Open the file in a browser and go to section **2** (ids `#2a`, `#2b`). Section **1b** shows the original 2-pet version, including the seizure details screen. Section **0** is the current app, for reference.

## State
- `selectedPetId`: defaults to the last-logged pet, then the first pet.
- `recentLogsProvider`: the latest N logs across all of the household's pets. This needs a query per pet that is then merged, or a collection-group query on `symptomLogs` ordered by `occurredAt`. Check that `firestore.rules` and the indexes cover the option you pick.
- `recentOtherTitles(petId)`: distinct titles from the pet's latest `other` logs.
- Requires the symptom catalog (`catalog/symptoms` plus a bundled copy) from docs/data-model.md.

## Design tokens
Build these as a custom `ThemeExtension` or `ColorScheme`. They replace the current `ColorScheme.fromSeed(Colors.teal)`.

| Token | Light | Dark |
|---|---|---|
| bg | #F9F6F2 | #120F0C |
| surf | #FEFDFB | #1E1A16 |
| ink | #241E1A | #F0EEEA |
| mute | #69625D | #A9A49E |
| line | #E1DDD8 | #322D29 |
| acc (primary) | #007B70 | #5CC6B9 |
| on acc | #FFFFFF | #011613 |
| accSoft | #CFF0EB | #0C3531 |
| accText | #00554D | #93E3D8 |

Pet avatar pairs (fill / initial), assigned by the pet's order in the list and cycling:
1. teal #CFF0EB / #00554D
2. terracotta #FEE5DC / #833F27
3. violet #EBE3FC / #544272
4. amber #F8EACE / #6B4716

Symptom dots: Seizure #9274C3 · Vomit #CC9C42 · Diarrhea #C26B4C · Other #948274.

The source oklch values are in the HTML. Dark-mode values for the avatar and dot colours aren't specified yet; see 1d for the dark direction.

- **Type:**
  - UI: Figtree (Google Fonts) at 400/500/600/700.
  - Times: IBM Plex Mono 400/500, 12px.
  - Scale: 22 (app bar), 17 (button), 16 (sheet rows), 15 (names, list titles), 13 (meta, labels), 12 (small).
- **Radii:** 30 (primary button), 28 (sheet top), 24 (pills), 20 (cards), 17 (chips), 14 (inputs).
- **Spacing:** 4/6/8/10/12/14/16/20/22.
- **Icons:** Material Symbols Rounded, weight 400, fill 0. Icons used: `add`, `settings`, `chevron_right`, `check`, `edit`, `close`.

## Files
- `Pet Health Tracker.dc.html`: all screens. Sections 2a and 2b are the target; 1b, 1d and 0 are context.
- In the repo, the screens these touch: `lib/features/household/home_screen.dart`, `lib/features/pets/pet_list.dart`, `lib/features/symptoms/log_symptom_screen.dart`, `lib/data/symptom_log.dart`, `lib/core/app.dart` (theme).
