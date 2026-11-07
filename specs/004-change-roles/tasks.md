# Tasks: Changing roles

**Spec**: [spec.md](spec.md) | **Plan**: [plan.md](plan.md)

One commit per task, each safe to ship on its own.

- [x] T001 Rules: the owner promotes or demotes one person at a time. Allow and deny tests in `firestore-tests/`.
- [x] T002 Repository: `makeAdmin` and `removeAdmin` on `HouseholdRepository`, which add or take out the uid in `adminIds`. Integration test against the real rules.
- [x] T003 Members screen menu: the remove button becomes "Remove from household" in a ⋮ menu, working as before.
- [x] T004 Role actions: the owner's menu gets "Make admin" or "Remove as admin", each after confirming.
