# Tasks: Removing members

**Spec**: [spec.md](spec.md) | **Plan**: [plan.md](plan.md)

One commit per task, each safe to ship on its own.

- [x] T001 Rules: narrow admin household updates to the writes in [plan.md](plan.md), and let admins remove someone and delete their member doc. Allow and deny tests in `firestore-tests/`.
- [x] T002 Repository: `removeMember`, which reads the household's invites from the server and writes one batch that takes the person out of `memberIds` and `adminIds`, deletes their member doc and deletes the invites. Integration test against the real rules.
- [x] T003 Members screen: Settings, Members, for everyone. Names sorted like Transfer ownership, with "Owner", "Admin" and "You" labels.
- [x] T004 Remove from the Members screen: admins see a remove action on each person they're allowed to remove. A confirm dialog says the active invite code stops working, then progress while it waits for the server, and an error snackbar on failure.
