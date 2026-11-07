# Implementation Plan: Removing members

**Spec**: [spec.md](spec.md)

## Rules
Before this work, the admin branch of the household update rule allowed any change to `memberIds` and `adminIds` that kept admins as members and kept the owner. That let an admin remove someone, but also add any uid or make anyone an admin. The rule is narrowed to what the app writes:
- renaming,
- the owner transferring ownership (`ownerId`, and the new owner added to `adminIds`),
- an admin who isn't the owner leaving (their uid out of both lists),
- removing one person: their uid out of `memberIds`, and out of `adminIds` too when the owner removes an admin. The person isn't the caller or the owner, and is an admin only when the caller is the owner.

No other change to `adminIds` was allowed, so the narrowed rule had no write that promotes or demotes anyone. [Changing roles](../004-change-roles/spec.md) adds the owner's.

The member doc delete rule also allows an admin to delete a removed person's doc, in the batch that takes them out of `memberIds`, under the same who-removes-whom check. Admins can already delete the household's invites.
