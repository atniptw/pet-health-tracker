# Feature Specification: Removing members

**Status**: Shipped | **Created**: 2026-10-24

## Overview
Admins can remove people from a household. Everyone can see who's in it, from a Members screen in Settings, and admins remove people from there. The data model's roles and the removal rules are in [data-model.md](../../docs/data-model.md) (Households and roles, Removing).

## Decisions
- **Who removes whom:** any admin can remove a member who isn't an admin. Only the owner can remove an admin. Nobody can remove the owner.
- **The invite code:** removing someone also deletes the household's active invite, in the same batch, so they can't rejoin with it. Admins make a new code to invite anyone else.
- **The members list:** everyone in the household sees it, with each person's name and whether they're the owner or an admin. Admins see the remove action.
- **What the removed person sees:** the household disappears, the same as when the owner deletes it. The app opens their other household, or the create and join choice. No message.
- **Their name and logs:** the same as leaving. Their member doc is deleted in the removal batch, and their logs stay with the household and show "Former member".
- **Waiting for the server:** removing waits for the server and shows progress, like deleting a household. It reads the household's invites from the server first, so it can't miss an active code only the server knows about. With no connection it fails and says to check the connection.
