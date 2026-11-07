# Tasks: Archiving pets

**Spec**: [spec.md](spec.md) | **Plan**: [plan.md](plan.md)

One commit per task, each safe to ship on its own.

- [x] T001 Repository: `archivePet`, `unarchivePet` and `watchArchivedPets` on `PetRepository`. Rules tests that admins can unarchive and members can't archive or unarchive. Integration test against the real rules.
- [x] T002 Refactor: split `PetFormScreen.build`, which is at its size baseline and can't grow.
- [x] T003 Archived pets: the "Archived pets" list in Settings, with each pet's history and admins' "Unarchive". It comes before archiving so an archived pet can always be brought back.
- [x] T004 Archiving: the edit screen's "Archive pet" button, after confirming.
