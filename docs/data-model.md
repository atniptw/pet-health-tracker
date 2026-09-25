# Data model

Status: planning. Nothing here is implemented. See [architecture.md](architecture.md) for the stack.

## Scope

- **v1:** pets and symptom logs.
- **Later:** medications and vet visits, as `pets/{petId}/medications` and `pets/{petId}/vetVisits`, siblings of `symptomLogs`. Adding them changes nothing below.
- **Species:** dog, cat, other.
- **Point-in-time logs:** each log is a single moment. No duration or resolved state.

## Collections

### `pets/{petId}`

| Field | Type | Notes |
|---|---|---|
| `name` | string | required |
| `species` | string | key: `dog`, `cat`, `other` |
| `breed` | string? | free text |
| `birthDate` | timestamp? | optional; owners often only know roughly |
| `sex` | string? | `female`, `male`, `unknown` |
| `photoPath` | string? | Storage path, later |
| `memberIds` | list of uid | non-empty; the creator is always a member |
| `createdAt`, `updatedAt` | server timestamp | |
| `archivedAt` | timestamp? | soft delete, keeps history |
| `schemaVersion` | int | evolve fields without a migration job |

Pets are top-level with `memberIds` rather than nested under `users/{uid}`, so sharing with a partner or vet later means adding a uid, with no data migration. "My pets" is `where memberIds array-contains uid`.

### `pets/{petId}/symptomLogs/{logId}`

| Field | Type | Notes |
|---|---|---|
| `symptom` | string | catalog key, or `other` |
| `customLabel` | string? | only when `symptom` is `other` |
| `severity` | int | 1 to 3 (mild, moderate, severe). See open question 1 |
| `answers` | map? | answers to the symptom's catalog questions, keyed by question key. See Symptom catalog |
| `occurredAt` | timestamp | defaults to now, can be backdated; stored UTC, shown local |
| `notes` | string? | |
| `photoPaths` | list? | later |
| `createdAt`, `updatedAt` | server timestamp | `occurredAt` is when it happened, `createdAt` is when it was logged |
| `schemaVersion` | int | |

One symptom per log: one tap to log, and per-symptom trends are simple queries. Several symptoms means several quick entries.

## Symptom catalog

An enum in app code: stable key, icon, label, applicable species (e.g. hairballs are cat-only), and an ordered list of **questions** specific to that symptom. Questions are defined by the app, not by users, and live in code. Firestore stores only keys and answers, so renaming a label never touches data.

Example: `vomiting` asks how many times (number), whether blood is present (yes/no), and what it looked like (single choice). A log stores `answers: { times: 3, blood: true, appearance: "foamy" }`.

**Question types:** yes/no, single choice, multiple choice, number, free text. Each question has a stable `key`, a label, a type, and (for choices) a list of options with their own stable keys. Answer values are stored as bool, string (choice key), list of strings, number, or string respectively.

**Evolution rules** (they keep old logs valid, since the definitions are not in Firestore):
- Never change a question's `key`, type, or option keys, and never reuse a retired key for something else. Add a new key instead.
- New questions are additive. Old logs simply lack an answer, so every question is optional at read time.
- A removed question stays in old logs. The UI ignores answers whose key is no longer in the catalog.
- Answers should be quick to give: defaults or a skip, never a blocking form.

## Conventions

- **Deletes:** pets are archived; logs are hard-deleted, with an undo snackbar.
- **Indexes:** the main query (a pet's logs by `occurredAt` descending) needs no custom index. Filtering by symptom needs a composite index on `(symptom, occurredAt)`, added when building trends.
- **Security rules:** caller must be in `memberIds`; `severity` in range; string lengths capped.
- **Users:** no `users/{uid}` profile doc in v1. Auth holds name and email. Add it when household sharing needs it.

## Open questions

### 1. Severity

Does severity stay a required top-level field (default "moderate", comparable across all symptoms), or become just another question on symptoms where it makes sense? A top-level field keeps cross-symptom trends simple.

## Decided

- **Custom questions per symptom type are app-defined** (in the catalog, above). Owner-defined or per-pet questions are out of scope for v1. If added later, logs would need to snapshot or version the question they answered.
