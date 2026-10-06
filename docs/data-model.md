# Data model

Status: partly implemented. Creating a household (not joining one), adding, listing and editing pets, logging and editing `other` symptoms (title, time, notes) and listing a pet's logs, the symptom catalog (bundled copy, publish script, and the app reading it to label logs), answering a catalog log's questions and editing its note from a pet's log history, and the security rules in `firestore.rules` are built; creating catalog logs and deleting logs exist in the data layer (`SymptomLogRepository`) but no screen uses them yet; archiving pets and medications are not built. See [architecture.md](architecture.md) for the stack.

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

A user does not get a household automatically. After sign-in, if they aren't already in a household, the app shows a choice: **join** an existing household with an invite code, or **create** a new one. Creating one makes the new user its sole admin, with a default name of `{display name}'s Household`.

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

### `catalog/symptoms`

A single doc holding the whole symptom catalog. See Symptom catalog.

| Field | Type | Notes |
|---|---|---|
| `catalogVersion` | int | incremented on every publish |
| `formatVersion` | int | version of the catalog's structure and question types |
| `symptoms` | list of maps | in display order. Each: `key`, `label`, `retired?`, `questions` |
| `updatedAt` | server timestamp | |

Each question is a map: `key`, `label`, `type`, `retired?`, for number types an optional `unit` (`seconds`), and for choice types `options`, a list of `{key, label, retired?}`.

## Security rules

Rules are checked against the household doc's `memberIds` and `adminIds`:

- **Household doc:** read if in `memberIds`; update and delete if in `adminIds`. Rules keep `adminIds` a non-empty subset of `memberIds`.
- **Pets:** read if in `memberIds`; create, update, delete if in `adminIds`. Creates and updates must match the pet schema above: `name` 1 to 100 characters, a known `species` and `sex`, `breed` up to 100 characters, `birthDate` as `YYYY-MM-DD`, server timestamps, no other fields. A new pet can't be archived, and updates keep `createdAt`.
- **Symptom logs:** read and create if in `memberIds` (with `createdBy` set to the caller); update and delete if the caller is `createdBy` or in `adminIds`. `createdBy` and `createdAt` cannot be changed. Creates and updates must match the log schema above: a `symptom` key of 1 to 50 characters, a `title` of 1 to 100 characters when `symptom` is `other` and no `title` otherwise, `answers` a map, `occurredAt` a timestamp, `notes` up to 2000 characters, server timestamps, no other fields.
- **Medications:** read if in `memberIds`; create, update, delete if in `adminIds`.
- **Catalog:** read if signed in; no client writes.
- String lengths capped.

## Symptom catalog

The symptoms and their questions live in Firestore in `catalog/symptoms`, so new symptoms, questions and options need no app release, and older app versions can show symptoms added after they shipped. A log stores only the symptom key and the answers, so renaming a label never touches data.

- **Source of truth:** `assets/catalog/symptoms.json` (`formatVersion` and `symptoms`). The app bundles this same file.
- **Bundled copy:** the app uses it until the Firestore doc has been read, and when no catalog is published or it can't be read. After that, Firestore's offline cache keeps the fetched version available.
- **Key checks:** `test/data/catalog_file_test.dart` checks that keys are unique and have labels, that question types are known, and that the file's keys match `test/data/catalog_keys.txt`. That list records every symptom, question (with its type), unit and option key; new keys and units get a line, and lines are never removed or changed, so a key can't be removed, reused or change type.
- **Publishing:** `scripts/publish-catalog.sh` writes the committed file to `catalog/symptoms` with the Admin SDK from a developer machine (works on the Spark plan), using Application Default Credentials (`gcloud auth application-default login`). It runs the key checks first, bumps `catalogVersion`, and refuses if any already-published key or unit is missing or has changed, for example when publishing from an out-of-date checkout. Publish after the change is on `main`.
- **`other`** is not a catalog entry. It is handled by the app, since it is the only symptom with a stored `title`.

Every log has a title and notes. The catalog currently has `seizure`, `vomit` and `diarrhea`, with the questions below.

### Other

Example log, with a stored `title` and no `answers`: `symptom: "other", title: "Ate a sock", notes: "Found chewing it around 2pm, some fabric missing"`.

### Seizure questions

| Key | Type | Notes |
|---|---|---|
| `durationSeconds` | number | unit `seconds` |
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

A yes/no answer is stored only when true, so a missing answer means "not noted", not "no". Other answers are stored as: single choice, the option key; multiple choice, a list of option keys; number, a whole number; free text, a string. An answer that is cleared is removed.

Question mechanics:
- **Question types:** yes/no, single choice, multiple choice, number, free text. Each question has a stable `key`, a label, a type, and for choices a list of options with stable keys.
- **Keys are permanent:** never change a question's key, type, unit or option keys, and never reuse a retired key. A number question with no unit can be given one.
- **Retire, don't remove:** a symptom, question or option that is no longer offered stays in the catalog with `retired: true`. It is hidden when logging but still labels old logs.
- **Every question is optional at read time,** since old logs lack answers to newer questions.
- **New question types need an app update.** Adding one bumps `formatVersion`. An app that sees a question type it doesn't know skips that question.
- **Edits keep unknown answers:** editing a log writes only the changed answer fields, so answers the app doesn't know about are kept.

## Conventions

- **Deletes:** pets are archived; logs are hard-deleted (by their author or an admin).
- **Indexes:** the main query (a pet's logs by `occurredAt` descending) needs no custom index. Filtering by symptom needs a composite index on `(symptom, occurredAt)`.

## Open questions

1. **How do admins add and remove members?** Removing is settled: an admin removes the uid from `memberIds` and `adminIds`, and a household keeps at least one admin. Adding is proposed but not confirmed: **invite codes, redeemed with security rules only** (no Cloud Functions, since those need a paid plan; see architecture.md).
   - An admin creates `invites/{code}`, a top-level doc with `householdId`, `createdBy`, `expiresAt` and `redeemedBy` (null until used). The code is a long random string, so it can't be guessed. Signed-in users can `get` an invite by its exact code but cannot list invites.
   - The admin shares the code with the person, for example via the phone's share sheet. The person enters it in the app.
   - The app redeems it with one batched write: set `redeemedBy` to the caller and add the caller to the household's `memberIds`. The household update rule allows a non-admin to do this only when the change is exactly "add my own uid to `memberIds`", the invite exists, is unredeemed and unexpired, points at this household, and the same batch marks it redeemed (using `getAfter`).
   - The invitee joins as a member. Admins promote from there.
   - This works the same for Google and Apple users. Whether it holds up in the rules emulator still needs to be proven with rules tests.
2. **How are members shown by name?** Logs record `createdBy` as a uid, but names come from somewhere. This is tied to how members join (question 1).
