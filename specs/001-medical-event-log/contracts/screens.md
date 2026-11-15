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

## First pet

- Shown whenever there are no active pets (story 3 scenario 1; edge case: last active pet archived).
- "Add your first pet": name field, species choices, "Save". Save is enabled once a name is entered.
- If archived pets exist, a "See archived pets" link opens Archived pets.

## Log (home screen)

- **Pet**: one active pet → its name shown as a heading, no picker. Several → a row of pet choices with the picked pet highlighted, or "Who is this for?" when none is picked (FR-007, research §9).
- **Types**: a grid of large buttons, one per offered type (`watchOffered`), and a last button "Something else".
- "History" opens Pet history for the picked pet; it is disabled when none is picked.
- Menu: "Pets", "My event types".
- After a save, a "Saved: <type> for <pet>" message.

## Log sheet

Opened from a type button, or from "Something else" (which first shows a text field "What happened?"; a typed name that matches an existing type, ignoring capitalization and spacing, uses that type).

- Header: the type name and the pet. With several pets and none picked, the pet choices appear here and "Save" stays disabled until one is chosen (story 1 scenario 3).
- "When": "Now" by default; tapping opens date and time pickers that stop at now (FR-003).
- The type's detail questions, each optional: choice questions as a row of choice chips (tap again to clear), duration as minutes and seconds fields (FR-006).
- "Note (optional)" text field.
- "Save" is enabled as soon as a pet is picked (FR-005). Saving a time after now shows "That time is in the future" and stays open.

## Pet history

- Title: the pet's name; "Archived" shown under it for an archived pet.
- **Summary** (FR-010): period choice "30 days", "90 days" (default), "12 months", "All time"; then one row per type the pet has had in the period: name, "<n> times", "about every <gap>" when the count is 2 or more, and "last <ago> ago". With no events in the period: "Nothing logged in this period".
- **Events** (FR-008, FR-009): newest first, each with date and time, type, its answered details, note, and "<gap> since the previous one" when there is an earlier event of the same type. No error or gap for the first of a type.
- Actions: "Edit pet" (Pet form), "Archive" (active pet) or "Restore" (archived pet).

## Event

- Opened from Pet history. The same fields as the Log sheet, filled in, plus the pet (active pets, and the event's own pet if archived) and the type (`watchOffered` plus the event's own type).
- "Save" applies the changes (FR-011, story 1 scenario 8). "Delete" asks "Delete this event?" with "Delete" and "Cancel"; on Delete it returns to Pet history.

## Pet form

- Add or edit: name, species, "Save". Editing keeps the pet's events (story 3 scenario 2).

## Pets

- Active pets by name, each opening Pet history; "Add pet"; "Archived pets".

## Archived pets

- Archived pets by name, each opening its Pet history, where "Restore" is offered (story 3 scenarios 3–4). With none: "No archived pets".

## My event types

- The custom types still offered, each with "Remove" (FR-004). With none: "Types you type in yourself appear here".
- Removing asks nothing further: the type can be brought back by typing it again, and past events keep it.
