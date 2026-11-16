# Data Model: Medical Event Log

Entities from the spec's Key Entities, as Dart types in `lib/domain/` and as tables in the local SQLite database (`lib/data/local/`). Decisions behind them are in `research.md`.

## Pet

| Field | Type | Rules |
|-------|------|-------|
| `id` | String (UUID v4) | Made on the phone; never changes |
| `name` | String | Required; trimmed; 1–40 characters |
| `species` | `Species` | One of `dog`, `cat`, `other` |
| `archived` | bool | `false` when added |
| `createdAt` | DateTime (UTC) | Set when added |

- Renaming or changing species keeps the `id`, so its events stay with it (story 3 scenario 2).
- States: **active** ⇄ **archived** (archive and restore, FR-015). Pets are never deleted in this feature.
- Active pets are listed by name; archived pets likewise, on their own list. By name means ignoring case (`toLowerCase()`), then by `id` for pets with the same name (D-003).

## Event type

Two kinds behind one `EventType` value:

| Field | Type | Rules |
|-------|------|-------|
| `id` | String | Built-in: fixed id (`vomiting`, …, research §5). Custom: UUID v4 |
| `name` | String | Built-in: fixed. Custom: as typed, trimmed and inner spaces collapsed; 1–40 characters |
| `builtIn` | bool | |
| `questions` | List<`DetailQuestion`> | Built-in: research §5. Custom: empty |
| `removed` | bool | Custom only; `true` once removed from the list |

- Built-in types live in code (`lib/domain/built_in_event_types.dart`) and can't be removed. Custom types are rows in the database.
- Names are unique by their match key (research §7): trimmed, spaces collapsed, lower-cased. A typed name matching a removed custom type sets `removed` back to `false`.
- The logging list shows the built-in types in their fixed order, then the custom types that aren't removed, by name.
- States of a custom type: **offered** → **removed** (FR-004) → **offered** again when typed.

### DetailQuestion

A sealed class; each subclass is one kind of question and owns its answer rules (research §5).

| Field | Type | Rules |
|-------|------|-------|
| `id` | String | Unique within its type, e.g. `duration`, `kind`; never changed or reused |
| `label` | String | Shown to the caregiver; can change |

| Kind | Extra fields | Answer stored as |
|------|--------------|------------------|
| `ChoiceQuestion` | `options`: List<(id, label)>, option ids never changed or reused | the option id (String) |
| `DurationQuestion` | none | whole seconds (int, ≥ 1) |

Each kind has `bool accepts(Object answer)` and `String describe(Object answer)` (how the history writes it out, e.g. "Grand mal", "2 min 30 s").

## Event

| Field | Type | Rules |
|-------|------|-------|
| `id` | String (UUID v4) | |
| `petId` | String | Required; an active pet when logging or changing the pet (FR-015) |
| `typeId` | String | Required (FR-005); a built-in id or a custom type's id, which stays valid after the type is removed |
| `occurredAt` | DateTime (UTC) | Defaults to now; never after now when saved (FR-003, edge case) |
| `details` | Map<String, Object> | Optional; keys are the type's question ids. `choice` → option id (String); `duration` → whole seconds (int, ≥ 1) |
| `note` | String? | Optional; trimmed, empty becomes null; up to 1000 characters |
| `createdAt` | DateTime (UTC) | Set when logged |
| `updatedAt` | DateTime (UTC) | Set when logged and on every edit |

- An event belongs to exactly one pet (spec Key Entities); there is no multi-pet event.
- Changing an event's type keeps only the details whose question ids the new type also has.
- Deleting an event removes the row (FR-011); there is no undo.
- Duplicates seconds apart are both kept (edge case).

## Settings

| Key | Value |
|-----|-------|
| `last_logged_pet_id` | The pet of the most recently saved new event (research §9) |

## Derived values (not stored)

Computed in `lib/domain/frequency.dart` from a pet's events (research §8):

- `timeSincePrevious(event)` → Duration?
- `TypeSummary(typeId, count, averageGap?, lastAt)` per type, for a `Period` of `last30Days`, `last90Days` (default), `last12Months` or `allTime`.

## SQLite schema (version 1)

```sql
CREATE TABLE pets (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  species TEXT NOT NULL,
  archived INTEGER NOT NULL DEFAULT 0,
  created_at INTEGER NOT NULL
);

CREATE TABLE event_types (          -- custom types only
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  match_key TEXT NOT NULL UNIQUE,
  removed INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE events (
  id TEXT PRIMARY KEY,
  pet_id TEXT NOT NULL REFERENCES pets(id),
  type_id TEXT NOT NULL,
  occurred_at INTEGER NOT NULL,     -- UTC ms since epoch
  details TEXT NOT NULL DEFAULT '{}', -- JSON object
  note TEXT,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);
CREATE INDEX events_pet_time ON events (pet_id, occurred_at DESC);

CREATE TABLE settings (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL
);
```

- `PRAGMA foreign_keys = ON` when the database opens.
- A built-in type's name is never stored in `event_types`, so built-in names can't collide with custom rows; matching (research §7) checks the built-in names in code first.
- The schema is created at version 1. A schema change bumps the version and migrates existing rows in `onUpgrade`, so no logged event is lost (SC-004).
