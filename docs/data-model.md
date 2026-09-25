# Data model

Status: planning. Nothing here is implemented. See [architecture.md](architecture.md) for the stack.

## Scope

- Households, their members, pets, and symptom logs.
- Species: dog, cat, other.
- Each log is a single moment. No duration or resolved state.

## Households and roles

A household has members and pets. Every member can see the household's pets and symptom logs and can add symptoms. A household has one or more **admins**.

| Action | Member | Admin |
|---|---|---|
| See the household, its pets and logs | yes | yes |
| Add symptom logs | yes | yes |
| Edit or delete symptom logs | no | yes |
| Add, edit, archive pets | no | yes |
| Add or remove members, change roles | no | yes |
| Edit or delete the household | no | yes |

A household always has at least one admin.

## Collections

### `households/{householdId}`

| Field | Type | Notes |
|---|---|---|
| `name` | string | required |
| `memberIds` | list of uid | everyone in the household, admins included; non-empty |
| `adminIds` | list of uid | subset of `memberIds`; non-empty |
| `createdAt`, `updatedAt` | server timestamp | |
| `schemaVersion` | int | evolve fields without a migration job |

Membership and role live on the household doc as two arrays, so security rules can check a user's role with a single read of this doc, and "my households" is `where memberIds array-contains uid`.

### `households/{householdId}/pets/{petId}`

A pet belongs to exactly one household, so it is nested under it.

| Field | Type | Notes |
|---|---|---|
| `name` | string | required |
| `species` | string | key: `dog`, `cat`, `other` |
| `breed` | string? | free text |
| `birthDate` | timestamp? | optional; owners often only know roughly |
| `sex` | string? | `female`, `male`, `unknown` |
| `createdAt`, `updatedAt` | server timestamp | |
| `archivedAt` | timestamp? | soft delete, keeps history |
| `schemaVersion` | int | |

### `households/{householdId}/pets/{petId}/symptomLogs/{logId}`

| Field | Type | Notes |
|---|---|---|
| `symptom` | string | catalog key, or `other` |
| `customLabel` | string? | only when `symptom` is `other` |
| `severity` | int | 1 to 3 (mild, moderate, severe). See open question 4 |
| `answers` | map? | answers to the symptom's questions, keyed by question key. See Symptom catalog |
| `occurredAt` | timestamp | defaults to now, can be backdated; stored UTC, shown local |
| `notes` | string? | |
| `createdAt`, `updatedAt` | server timestamp | `occurredAt` is when it happened, `createdAt` is when it was logged |
| `schemaVersion` | int | |

One symptom per log: one tap to log, and per-symptom queries are simple. Several symptoms means several quick entries.

## Security rules

Rules are checked against the household doc's `memberIds` and `adminIds`:

- **Household doc:** read if in `memberIds`; update and delete if in `adminIds`. Rules keep `adminIds` a non-empty subset of `memberIds`.
- **Pets:** read if in `memberIds`; create, update, delete if in `adminIds`.
- **Symptom logs:** read and create if in `memberIds`; update and delete if in `adminIds`.
- `severity` in range; string lengths capped.

## Symptom catalog

The symptoms, and the questions asked for each symptom, are defined in the app (in code), not by users and not in Firestore. Each catalog entry has a stable key, an icon, a label, applicable species (e.g. hairballs are cat-only), and an ordered list of questions. Firestore stores only symptom keys and answers, so renaming a label never touches data.

Which questions each symptom gets has not been decided yet. See open question 2.

Illustrative example only: `vomiting` might ask how many times (number), whether blood is present (yes/no), and what it looked like (single choice), stored as `answers: { times: 3, blood: true, appearance: "foamy" }`.

Proposed mechanics, to be settled along with the questions themselves:
- **Question types:** yes/no, single choice, multiple choice, number, free text. Each question has a stable `key`, a label, a type, and for choices a list of options with stable keys.
- **Keys are permanent:** never change a question's key, type, or option keys, and never reuse a retired key.
- **Every question is optional at read time,** since old logs lack answers to newer questions. The UI ignores answers whose key is no longer in the catalog.

## Conventions

- **Deletes:** pets are archived; logs are hard-deleted (admins only).
- **Indexes:** the main query (a pet's logs by `occurredAt` descending) needs no custom index. Filtering by symptom needs a composite index on `(symptom, occurredAt)`.

## Decided

- The symptoms and the questions for each symptom are defined in the app.
- Households have members and pets. All members can see and add symptoms.
- Households have one or more admins. Admins add and remove members and have full edit control. Non-admins can only add symptoms.

## Open questions

1. **How do members join a household?** An admin adds and removes members, but how the person is identified and how they accept (email invite, invite code, link, something else) is not decided. This also decides whether we need a `users/{uid}` profile doc.
2. **Which questions does each symptom get?** The next thing to work out, symptom by symptom, including which symptoms are in the catalog.
3. **Household creation and count:** does a user get a household automatically on first sign-in, including anonymous users? Can a user belong to more than one household?
4. **Severity:** does it stay a required top-level field (default "moderate", comparable across all symptoms), or become just another question on symptoms where it makes sense?
5. **Non-admin mistakes:** members can only add symptoms, so a member can't fix or delete a log they entered by mistake. Is that intended, or can members edit or delete their own logs?
6. **Who logged it:** should a log record which member added it, and how are members shown by name?
