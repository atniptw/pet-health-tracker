# Data model

Status: planning. Nothing here is implemented. See [architecture.md](architecture.md) for the stack.

## Scope

- Households, their members, pets, symptom logs, and a list of medications per pet.
- Species: dog, cat, other.
- Each log is a single moment. No duration or resolved state.

## Households and roles

A household has members and pets. Every member can see the household's pets and symptom logs, can add symptoms, and can edit and delete their own symptom entries. A household has one or more **admins**. A person can belong to multiple households.

| Action | Member | Admin |
|---|---|---|
| See the household, its pets and logs | yes | yes |
| Add symptom logs | yes | yes |
| Edit symptom logs | own entries only | all |
| Delete symptom logs | own entries only | all |
| Add, edit, delete medications | no | yes |
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
| `birthDate` | string? | `YYYY-MM-DD` calendar date, no timezone; optional, owners often only know roughly |
| `sex` | string? | `female`, `male`, `unknown` |
| `createdAt`, `updatedAt` | server timestamp | |
| `archivedAt` | timestamp? | soft delete, keeps history |
| `schemaVersion` | int | |

### `households/{householdId}/pets/{petId}/symptomLogs/{logId}`

| Field | Type | Notes |
|---|---|---|
| `symptom` | string | catalog key (e.g. `seizure`, `vomit`), or `other` |
| `title` | string? | short title, only when `symptom` is `other`. For every other symptom the title is the catalog label, so it isn't stored |
| `createdBy` | string | uid of the member who added it; never changes. Identifies "own entries" |
| `answers` | map? | type-specific fields, keyed by question key. See Symptom catalog |
| `occurredAt` | timestamp | when it happened; stored UTC |
| `notes` | string? | |
| `createdAt`, `updatedAt` | server timestamp | `occurredAt` is when it happened, `createdAt` is when it was logged |
| `schemaVersion` | int | |

One symptom per log, so per-symptom queries are simple. Several symptoms means several entries.

### `households/{householdId}/pets/{petId}/medications/{medId}`

A simple list of the medications a pet is on. No schedule, dose tracking, or history.

| Field | Type | Notes |
|---|---|---|
| `name` | string | required |
| `notes` | string? | free text, e.g. dose and how often |
| `createdAt`, `updatedAt` | server timestamp | |
| `schemaVersion` | int | |

Medications are hard-deleted.

## Security rules

Rules are checked against the household doc's `memberIds` and `adminIds`:

- **Household doc:** read if in `memberIds`; update and delete if in `adminIds`. Rules keep `adminIds` a non-empty subset of `memberIds`.
- **Pets:** read if in `memberIds`; create, update, delete if in `adminIds`.
- **Symptom logs:** read and create if in `memberIds` (with `createdBy` set to the caller); update and delete if the caller is `createdBy` or in `adminIds`. `createdBy` cannot be changed.
- **Medications:** read if in `memberIds`; create, update, delete if in `adminIds`.
- String lengths capped.

## Symptom catalog

The symptoms and their questions are defined in the app, not in Firestore. A log stores only the symptom key and the answers, so renaming a label never touches data.

Every log has a title and notes. `seizure`, `vomit` and `diarrhea` have the questions below. Which questions the other symptoms get has not been decided yet. See open question 2.

### Other

Example log, with a stored `title` and no `answers`: `symptom: "other", title: "Ate a sock", notes: "Found chewing it around 2pm, some fabric missing"`.

### Seizure questions

| Key | Type | Notes |
|---|---|---|
| `durationSeconds` | number | seconds |
| `type` | single choice | `focal` (one area), `generalized` (full body), `notSure` |
| `lostConsciousness` | yes/no | unresponsive, not reacting |
| `urinated` | yes/no | |
| `defecated` | yes/no | |
| `foaming` | yes/no | foaming or drooling |

Example: `answers: { durationSeconds: 90, type: "generalized", urinated: true, foaming: true }`.

### Vomit questions

| Key | Type | Notes |
|---|---|---|
| `content` | single choice | `food`, `foamOrBile`, `clearLiquid`, `other` |
| `blood` | yes/no | |
| `retchingOnly` | yes/no | retching, nothing came up |
| `timing` | single choice | `rightAfterEating`, `hoursAfterEating`, `emptyStomach` |

Example: `answers: { content: "foamOrBile", timing: "emptyStomach" }`.

### Diarrhea questions

| Key | Type | Notes |
|---|---|---|
| `consistency` | single choice | `soft`, `watery` |
| `redBlood` | yes/no | |
| `blackTarry` | yes/no | a separate flag from red blood |
| `mucus` | yes/no | |
| `straining` | yes/no | |

Example: `answers: { consistency: "watery", mucus: true }`.

A yes/no answer is stored only when true, so a missing answer means "not noted", not "no".

Proposed mechanics, to be settled along with the questions themselves:
- **Question types:** yes/no, single choice, multiple choice, number, free text. Each question has a stable `key`, a label, a type, and for choices a list of options with stable keys.
- **Keys are permanent:** never change a question's key, type, or option keys, and never reuse a retired key.
- **Every question is optional at read time,** since old logs lack answers to newer questions. Answers whose key is no longer in the catalog are ignored.

## Conventions

- **Deletes:** pets are archived; logs are hard-deleted (by their author or an admin).
- **Indexes:** the main query (a pet's logs by `occurredAt` descending) needs no custom index. Filtering by symptom needs a composite index on `(symptom, occurredAt)`.

## Open questions

1. **How do admins add and remove members?** Removing is settled: an admin removes the uid from `memberIds` and `adminIds`, and a household keeps at least one admin. Adding is proposed but not confirmed: **invite codes, redeemed with security rules only** (no Cloud Functions, since those need a paid plan; see architecture.md).
   - An admin creates `invites/{code}`, a top-level doc with `householdId`, `createdBy`, `expiresAt` and `redeemedBy` (null until used). The code is a long random string, so it can't be guessed. Signed-in users can `get` an invite by its exact code but cannot list invites.
   - The admin shares the code with the person, for example via the phone's share sheet. The person enters it in the app.
   - The app redeems it with one batched write: set `redeemedBy` to the caller and add the caller to the household's `memberIds`. The household update rule allows a non-admin to do this only when the change is exactly "add my own uid to `memberIds`", the invite exists, is unredeemed and unexpired, points at this household, and the same batch marks it redeemed (using `getAfter`).
   - The invitee joins as a member. Admins promote from there.
   - This works the same for Google, Apple and anonymous users. Whether it holds up in the rules emulator still needs to be proven with rules tests.
2. **Which questions does each symptom get?** The next thing to work out, symptom by symptom, including which symptoms are in the catalog.
3. **Household creation:** does a user get a household automatically on first sign-in, including anonymous users?
4. **How are members shown by name?** Logs record `createdBy` as a uid, but names come from somewhere. This is tied to how members join (question 1).
