# Feature Specification: Changing roles

**Status**: Shipped | **Created**: 2026-10-24

## Overview
The owner can make a member an admin, and take admin away from an admin. It happens from the Members screen in Settings, whose rows get a menu of what the viewer can do to each person. The roles are in [data-model.md](../../docs/data-model.md) (Households and roles, Changing roles).

## Decisions
- **Who:** only the owner makes someone an admin or takes admin away. Admins who aren't the owner can't change anyone's role.
- **Stepping down:** an admin can't drop their own admin role. The owner can take it away, or they can leave. The owner is always an admin.
- **The Members screen:** each row with something the viewer can do has a ⋮ menu instead of the remove button. The owner sees "Make admin" or "Remove as admin", and "Remove from household". An admin who isn't the owner sees "Remove from household" on members who aren't admins. Rows with nothing to do have no menu.
- **Confirming:** changing a role asks first, like transferring ownership.
- **Waiting for the server:** changing a role doesn't wait, like transferring ownership and renaming. The new role shows right away from the local write.
