# Changing roles

## Overview
The owner can make a member an admin, and take admin away from an admin. It happens from the Members screen in Settings, whose rows get a menu of what the viewer can do to each person. The roles are in [data-model.md](../../data-model.md) (Households and roles).

## Decisions
- **Who:** only the owner makes someone an admin or takes admin away. Admins who aren't the owner can't change anyone's role.
- **Stepping down:** an admin can't drop their own admin role. The owner can take it away, or they can leave. The owner is always an admin.
- **The Members screen:** each row with something the viewer can do has a ⋮ menu instead of the remove button. The owner sees "Make admin" or "Remove as admin", and "Remove from household". An admin who isn't the owner sees "Remove from household" on members who aren't admins. Rows with nothing to do have no menu.
- **Confirming:** changing a role asks first, like transferring ownership.
- **Waiting for the server:** changing a role doesn't wait, like transferring ownership and renaming. The new role shows right away from the local write.

## Rules
The admin household update gains one more change to `adminIds`: the owner adds one member who isn't an admin, or takes out one admin who isn't the owner. `memberIds` and `ownerId` stay the same. Lists padded with duplicates are refused, as for removing.

## Build order
One commit per step, each safe to ship on its own.
1. Rules: the owner promotes or demotes one person at a time. Allow and deny tests in `firestore-tests/`. (done)
2. Repository: `makeAdmin` and `removeAdmin` on `HouseholdRepository`, which add or take out the uid in `adminIds`. Integration test against the real rules. (done)
3. Members screen menu: the remove button becomes "Remove from household" in a ⋮ menu, working as before.
4. Role actions: the owner's menu gets "Make admin" or "Remove as admin", each after confirming.
