# Data model

Status: planning. Nothing here is implemented. See [architecture.md](architecture.md) for the stack.

## Scope

- Pets and symptom logs.
- Species: dog, cat, other.
- Each log is a single moment. No duration or resolved state.

## Collections

### `pets/{petId}`

| Field | Type | Notes |
|---|---|---|
| `name` | string | required |
| `species` | string | key: `dog`, `cat`, `other` |
| `breed` | string? | free text |
| `birthDate` | timestamp? | optional; owners often only know roughly |
| `sex` | string? | `female`, `male`, `unknown` |
| `memberIds` | list of uid | non-empty; the creator is always a member |
| `createdAt`, `updatedAt` | server timestamp | |
| `archivedAt` | timestamp? | soft delete, keeps history |
| `schemaVersion` | int | evolve fields without a migration job |

"My pets" is `where memberIds array-contains uid`.

### `pets/{petId}/symptomLogs/{logId}`

| Field | Type | Notes |
|---|---|---|
| `symptom` | string | catalog key, or `other` |
| `customLabel` | string? | only when `symptom` is `other` |
| `severity` | int | 1 to 3 (mild, moderate, severe). See open question 1 |
| `answers` | map? | answers to the symptom's questions, keyed by question key. See Symptom catalog |
| `occurredAt` | timestamp | defaults to now, can be backdated; stored UTC, shown local |
| `notes` | string? | |
| `createdAt`, `updatedAt` | server timestamp | `occurredAt` is when it happened, `createdAt` is when it was logged |
| `schemaVersion` | int | |

One symptom per log: one tap to log, and per-symptom queries are simple. Several symptoms means several quick entries.

## Symptom catalog

The symptoms, and the questions asked for each symptom, are defined in the app (in code), not by users and not in Firestore. Each catalog entry has a stable key, an icon, a label, applicable species (e.g. hairballs are cat-only), and an ordered list of questions. Firestore stores only symptom keys and answers, so renaming a label never touches data.

Which questions each symptom gets has not been decided yet. See open question 2.

Illustrative example only: `vomiting` might ask how many times (number), whether blood is present (yes/no), and what it looked like (single choice), stored as `answers: { times: 3, blood: true, appearance: "foamy" }`.

Proposed mechanics, to be settled along with the questions themselves:
- **Question types:** yes/no, single choice, multiple choice, number, free text. Each question has a stable `key`, a label, a type, and for choices a list of options with stable keys.
- **Keys are permanent:** never change a question's key, type, or option keys, and never reuse a retired key.
- **Every question is optional at read time,** since old logs lack answers to newer questions. The UI ignores answers whose key is no longer in the catalog.

## Conventions

- **Deletes:** pets are archived; logs are hard-deleted, with an undo snackbar.
- **Indexes:** the main query (a pet's logs by `occurredAt` descending) needs no custom index. Filtering by symptom needs a composite index on `(symptom, occurredAt)`.
- **Security rules:** caller must be in `memberIds`; `severity` in range; string lengths capped.
- **Users:** no `users/{uid}` profile doc. Auth holds name and email.

## Decided

- The symptoms and the questions for each symptom are defined in the app.

## Open questions

1. **Severity:** does it stay a required top-level field (default "moderate", comparable across all symptoms), or become just another question on symptoms where it makes sense?
2. **Which questions does each symptom get?** This is the next thing to work out, symptom by symptom, including which symptoms are in the catalog.
