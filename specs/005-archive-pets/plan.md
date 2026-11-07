# Implementation Plan: Archiving pets

**Spec**: [spec.md](spec.md)

## Design choices
Archiving and unarchiving don't wait for the server, like editing a household's name; the pet moves between the lists right away from the local write. Unarchiving doesn't ask first, since it's undone by archiving again. The "Archived pets" tile shows only when the household has archived pets.
