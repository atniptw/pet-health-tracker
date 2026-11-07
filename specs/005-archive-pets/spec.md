# Feature Specification: Archiving pets

**Status**: Shipped | **Created**: 2026-10-25

## Overview
Admins can archive a pet, so it no longer shows when logging or on the home screen, and bring it back later. Its history is kept. The pet schema already has `archivedAt` ([data-model.md](../../docs/data-model.md), Pets), and the security rules already let admins set and clear it.

## Decisions
- **Where:** admins archive a pet from its edit screen (Settings, the pet), with an "Archive pet" button, after confirming.
- **Archived pets:** Settings gets an "Archived pets" list. Anyone can open an archived pet's history from it, and admins can unarchive a pet there.
- **Recent logs:** the home screen's Recent list leaves out archived pets' logs, as it does today.
