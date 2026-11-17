# Contract: Screens

What each screen shows and does, and how they connect. Widget tests check these behaviors. Wording in quotes is the text shown.

```text
App start
 ├─ no active pets ──► First pet ──(saved)──► Log
 └─ active pets ─────► Log (home)
                        ├─ tap a type / "Something else" ──► Log sheet ──(Save)──► Log, "Saved" message
                        ├─ "History" ──► Pet history ──(tap event)──► Event
                        │                  └─ "Edit pet" ──► Pet form / "Archive" / "Restore"
                        └─ menu ──► Pets ──► Pet history, Pet form (add), Archived pets
                              └──► My event types
```

## App start

- The start screen follows the active pets: First pet while there are none, Log otherwise.
- If the pets can't be read, the error is reported and the screen shown stays. If none have been read yet, it says "Your pets couldn't be loaded. Close the app and open it again." (D-017)

## First pet

- Shown whenever there are no active pets (story 3 scenario 1; edge case: last active pet archived).
- "Add your first pet": name field, species choices, "Save". Save is enabled once a name is entered.
- After a save, the screen keeps the entered name and species with "Save" disabled until the start screen choice replaces it (D-006).
- If archived pets exist, a "See archived pets" link opens Archived pets.

## Log (home screen)

- **Pet**: one active pet → its name shown as a heading, no picker. Several → a row of pet choices with the picked pet highlighted, or "Who is this for?" when none is picked; tapping the picked pet keeps it picked (FR-007, research §9, D-009).
- **Types**: a grid of large buttons, one per offered type (`watchOffered`), and a last button "Something else", outlined rather than filled since it is not a type (D-015).
- "History", a text button in the app bar next to the menu, opens Pet history for the picked pet; it is disabled when none is picked (D-026).
- Menu: "Pets", "My event types".
- After a save, a "Saved: <type> for <pet>" message, which replaces any earlier one at once (D-013), and the saved event's pet becomes the picked one.

## Log sheet

Opened from a type button, or from "Something else", which first shows a text field "What happened?" (up to 40 characters; typing stops there) and "Continue", disabled while the field is empty or only spaces; the keyboard's done key continues too (D-014). A typed name that matches an existing type, ignoring capitalization and spacing, uses that type, a removed custom type included, which is then offered again; any other name is a new type, trimmed and with inner runs of spaces collapsed. Closing "What happened?" opens no log sheet.

- Header: the type name and the pet. With several pets and none picked, the pet choices appear here and "Save" stays disabled until one is chosen (story 1 scenario 3). Once shown, the choices stay for the sheet's life, so a pet chosen there can be changed before saving (D-010).
- "When": "Now" by default; tapping opens date and time pickers that stop at now (FR-003). A time picked after now is not taken: the field keeps what it showed, with "That time is in the future" under it (D-007).
- The type's detail questions, each optional: choice questions as a row of choice chips (tap again to clear), duration as "Minutes" and "Seconds" number fields under the question, up to 3 and 2 digits, added up as typed, so 1 and 75 is 135 seconds; both empty or zero leaves it unanswered (FR-006, D-008).
- "Note (optional)" text field, up to 1000 characters; typing stops there.
- "Save" is enabled as soon as a pet is picked (FR-005) and disabled while saving. Saving a time after now shows "That time is in the future" under "When" and stays open; picking another time clears it (D-011). Once saved, the sheet closes with the saved event.

## Pet history

- Title: the pet's name; "Archived" shown under it for an archived pet.
- **Summary** (FR-010): period choice "30 days", "90 days" (default), "12 months", "All time"; then one row per type the pet has had in the period: name, "<n> times", "about every <gap>" when the count is 2 or more, and "last <ago> ago", the name as the row's title and the rest each on its own line under it; a type logged once reads "1 time" (D-024). With no events in the period: "Nothing logged in this period".
- **Events** (FR-008, FR-009): newest first, each with date and time, type, its answered details, note, and "<gap> since the previous one" when there is an earlier event of the same type. No error or gap for the first of a type. Each tile shows the type name, then the date and time in local time as "When" shows them ("Nov 13, 2026 9:30 PM"), each answered detail as "<question>: <answer>" in the type's question order, the note, and the gap (D-023).
- Actions: "Edit pet" (Pet form), a text button in the app bar (D-026), "Archive" (active pet) or "Restore" (archived pet). The title follows the pet, so a name changed through "Edit pet" shows on return.
- If the pet can't be read, the error is reported and the title stays. If its events can't be read, the error is reported and the history shown stays; if none have been read yet, it says "This pet's history couldn't be loaded. Close the app and open it again." (D-025)

## Event

- Opened from Pet history. The same fields as the Log sheet, filled in, plus the pet (active pets, and the event's own pet if archived) and the type (`watchOffered` plus the event's own type).
- "Save" applies the changes (FR-011, story 1 scenario 8). "Delete" asks "Delete this event?" with "Delete" and "Cancel"; on Delete it returns to Pet history.

## Pet form

- Add or edit: name, species, "Save". Editing keeps the pet's events (story 3 scenario 2).
- Adding starts with "Dog" picked, so "Save" needs only a name (D-005).

## Pets

- Active pets by name, each opening Pet history; "Add pet"; "Archived pets".

## Archived pets

- Archived pets by name, each opening its Pet history, where "Restore" is offered (story 3 scenarios 3–4). With none: "No archived pets".

## My event types

- The custom types still offered, each with "Remove" (FR-004). With none: "Types you type in yourself appear here".
- Removing asks nothing further: the type can be brought back by typing it again, and past events keep it.
- "Remove" is disabled while the type is being removed. If removing fails, the error is reported and "Remove" works again.
- If the types can't be read, the error is reported and the list shown stays. If none have been read yet, it says "Your event types couldn't be loaded. Close the app and open it again." (D-018)
