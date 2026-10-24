# Removing members

## Overview
Admins can remove people from a household. Everyone can see who's in it, from a Members screen in Settings, and admins remove people from there. The data model's roles and the removal rules are in [data-model.md](../../data-model.md) (Households and roles, Removing).

## Decisions
- **Who removes whom:** any admin can remove a member who isn't an admin. Only the owner can remove an admin. Nobody can remove the owner.
- **The invite code:** removing someone also deletes the household's active invite, in the same batch, so they can't rejoin with it. Admins make a new code to invite anyone else.
- **The members list:** everyone in the household sees it, with each person's name and whether they're the owner or an admin. Admins see the remove action.
- **What the removed person sees:** the household disappears, the same as when the owner deletes it. The app opens their other household, or the create and join choice. No message.
- **Their name and logs:** the same as leaving. Their member doc is deleted in the removal batch, and their logs stay with the household and show "Former member".
- **Waiting for the server:** removing waits for the server and shows progress, like deleting a household. It reads the household's invites from the server first, so it can't miss an active code only the server knows about. With no connection it fails and says to check the connection.

## Rules
Before this work, the admin branch of the household update rule allowed any change to `memberIds` and `adminIds` that kept admins as members and kept the owner. That let an admin remove someone, but also add any uid or make anyone an admin. The rule is narrowed to what the app writes:
- renaming,
- the owner transferring ownership (`ownerId`, and the new owner added to `adminIds`),
- an admin who isn't the owner leaving (their uid out of both lists),
- removing one person: their uid out of `memberIds`, and out of `adminIds` too when the owner removes an admin. The person isn't the caller or the owner, and is an admin only when the caller is the owner.

No other change to `adminIds` is allowed, so the narrowed rule has no write that promotes or demotes anyone. Nothing in the app changes roles.

The member doc delete rule also allows an admin to delete a removed person's doc, in the batch that takes them out of `memberIds`, under the same who-removes-whom check. Admins can already delete the household's invites.

## Build order
One commit per step, each safe to ship on its own.
1. Rules: narrow admin household updates to the writes above, and let admins remove someone and delete their member doc. Allow and deny tests in `firestore-tests/`. (done)
2. Repository: `removeMember`, which reads the household's invites from the server and writes one batch that takes the person out of `memberIds` and `adminIds`, deletes their member doc and deletes the invites. Integration test against the real rules. (done)
3. Members screen: Settings, Members, for everyone. Names sorted like Transfer ownership, with "Owner", "Admin" and "You" labels. (done)
4. Remove from the Members screen: admins see a remove action on each person they're allowed to remove. A confirm dialog says the active invite code stops working, then progress while it waits for the server, and an error snackbar on failure. (done)
