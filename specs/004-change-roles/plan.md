# Implementation Plan: Changing roles

**Spec**: [spec.md](spec.md)

## Rules
The admin household update gains one more change to `adminIds`: the owner adds one member who isn't an admin, or takes out one admin who isn't the owner. `memberIds` and `ownerId` stay the same. Lists padded with duplicates are refused, as for removing.
