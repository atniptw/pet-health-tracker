# Archiving pets

## Overview
Admins can archive a pet, so it no longer shows when logging or on the home screen, and bring it back later. Its history is kept. The pet schema already has `archivedAt` ([data-model.md](../../data-model.md), Pets), and the security rules already let admins set and clear it.

## Decisions
- **Where:** admins archive a pet from its edit screen (Settings, the pet), with an "Archive pet" button, after confirming.
- **Archived pets:** Settings gets an "Archived pets" list. Anyone can open an archived pet's history from it, and admins can unarchive a pet there.
- **Recent logs:** the home screen's Recent list leaves out archived pets' logs, as it does today.

My own choices: archiving and unarchiving don't wait for the server, like editing a household's name; the pet moves between the lists right away from the local write. Unarchiving doesn't ask first, since it's undone by archiving again. The "Archived pets" tile shows only when the household has archived pets.

## Build order
One commit per step, each safe to ship on its own.
1. Repository: `archivePet`, `unarchivePet` and `watchArchivedPets` on `PetRepository`. Rules tests that admins can unarchive and members can't archive or unarchive. Integration test against the real rules.
2. Refactor: split `PetFormScreen.build`, which is at its size baseline and can't grow.
3. Archived pets: the "Archived pets" list in Settings, with each pet's history and admins' "Unarchive". It comes before archiving so an archived pet can always be brought back.
4. Archiving: the edit screen's "Archive pet" button, after confirming.
