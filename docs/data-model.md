# Data model

Status: partly implemented. Creating a household with the creator's name, joining one with an invite code, leaving one (anyone but the owner, from Settings), asking existing members for their name once, showing who logged each entry in a pet's history, switching between households, admins renaming the household (Settings, Household name), the owner transferring ownership (Settings, Transfer ownership), the owner deleting the household (Settings, Delete household), deleting an account (Settings, Delete account; see architecture.md), admins making and sharing an invite code (Settings, Invite someone), adding, listing and editing pets, logging catalog and `other` symptoms from the home screen's sheet, editing `other` logs (title, time, notes), undoing a just-logged `other` log, deleting a log from its edit screen (its author or an admin, after confirming; like logging, it doesn't wait for the server), listing a pet's logs and the household's recent logs, the symptom catalog (bundled copy, publish script, and the app reading it to label logs), answering a catalog log's questions and editing its note and time, and the security rules in `firestore.rules` are built; archiving pets and medications are not built. See [architecture.md](architecture.md) for the stack.

## Scope

- Households, their members, pets, symptom logs, and a list of medications per pet.
- Species: dog, cat, other.
- Each log is a single moment. No duration or resolved state.

## Households and roles

A household has members and pets. Every member can see the household's pets and symptom logs, can add symptoms, and can edit and delete their own symptom entries. A household has one **owner** and one or more **admins**; the owner is also an admin. A person can belong to multiple households.

| Action | Member | Admin | Owner |
|---|---|---|---|
| See the household, its pets and logs | yes | yes | yes |
| Add symptom logs | yes | yes | yes |
| Edit symptom logs | own entries only | all | all |
| Delete symptom logs | own entries only | all | all |
| Add, edit, delete medications | no | yes | yes |
| Add, edit, archive pets | no | yes | yes |
| See and share the invite code | no | yes | yes |
| Remove members, change roles | no | yes | yes |
| Rename the household | no | yes | yes |
| Delete the household | no | no | yes |
| Transfer ownership | no | no | yes |
| Change their own name in the household | yes | yes | yes |
| Leave the household | yes | yes | no |

A household always has exactly one owner and at least one admin.

The owner can transfer ownership to any member, who becomes an admin and the owner. The old owner stays an admin. The owner does it from Settings (Transfer ownership, which lists the other members by name), after confirming; with no one else in the household the option is disabled, with "Invite someone first". Like renaming, it doesn't wait for the server.

A user does not get a household automatically. After sign-in, if they aren't already in a household, the app shows a choice: **join** an existing household with an invite code, or **create** a new one. Creating one makes the new user its owner and sole admin, with a default name of `{display name}'s Household`. People already in a household can join or create more.

### Multiple households

A person can be in several households. The app shows one household at a time and remembers the last-opened household on the device (`shared_preferences`, keyed by uid); without one it opens the first by name. Tapping the household name on the home screen opens a sheet to switch households or create another; a new household opens once created. After joining, the app opens the household just joined.

### Names

Each member has a name per household, so someone can be "Tom" in one and "Dad" in another. It is pre-filled from the login's display name. The creator sets theirs on the create screen and an invitee sets theirs when joining. A member with no name in a household (households created before names existed) is asked for one once, the next time they open it. The app asks only when the server confirms the name is missing, and shows the home screen until then, so logging without signal is never blocked. Anyone can change their own name.

A pet's history shows who logged each entry, once the household has more than one member. A log by someone else shows their name. A log by someone who has left the household, or deleted their account, shows "Former member". People who left before names were deleted on leaving keep their name. A member who hasn't given a name yet shows none.

### Invite codes

Admins add people with an invite code, redeemed with security rules only (no Cloud Functions, since those need a paid plan; see architecture.md). New people join as members, and admins promote from there. This works the same for Google and Apple users.

- **The code:** the app suggests three random words from the bundled EFF Short Wordlist 1 (1,296 words, CC BY 3.0, credited on the licenses page), picked again until the suggestion is at least 12 characters. The admin can regenerate the suggestion or type their own of at least 12 characters, any characters allowed.
- **Matching:** exact, after trimming trailing spaces. Autocorrect is off on the code field.
- **Reuse and expiry:** a code works for any number of people until it expires, 7 days after it is made. A household has one active code; making a new one replaces it, and the old one stops working.
- **Only the hash is stored:** Firestore keeps the code's SHA-256 hash, never the code. The raw code is kept only on the phone of the admin who made it, in secure storage (`flutter_secure_storage`; Android auto-backup is off so a restored backup can't leave unreadable values), keyed by account and household, and deleted when it expires. Other admins, or the same admin on another phone, see that a code is active and when it expires, and can make a new one to share.
- **Who sees it:** admins only.

### Renaming

An admin can rename the household from Settings (Household name), 1 to 100 characters. Like logging, the rename doesn't wait for the server; the new name shows right away.

### Leaving

Anyone but the owner can leave a household from Settings, after confirming; an admin who leaves stops being an admin. The owner sees the option disabled, with "The owner can't leave a household". Like logging, leaving doesn't wait for the server; the app returns to its root, which opens another household or the create and join choice. Leaving deletes their `members/{uid}` doc in the same batch; their logs stay with the household and show "Former member". If they join again they give their name again.

### Deleting

Only the owner can delete a household, from Settings (Delete household), after confirming. Unlike other changes, deleting waits for the server and shows progress; with no connection it fails and says to check the connection. It reads the household's pets with their symptom logs and medications, its invites and its member docs from the server, deletes all but the member docs in batches of up to 500 writes, then deletes the member docs and the household in one last batch. The household goes last because the rules for everything else need it to exist. The app then returns to its root, which opens another household or the create and join choice.

## Collections

### `households/{householdId}`

| Field | Type | Notes |
|---|---|---|
| `name` | string | required |
| `memberIds` | list of uid | everyone in the household, admins included; non-empty |
| `adminIds` | list of uid | subset of `memberIds`; non-empty |
| `ownerId` | uid | the owner, set to the creator. Households made before owners get one from `scripts/backfill-owners.sh`: a sole admin, else the admin who created it (a member doc with no `inviteId`), else the longest-standing admin |
| `createdAt`, `updatedAt` | server timestamp | |
| `schemaVersion` | int | evolve fields without a migration job |

Membership and role live on the household doc as two arrays, so security rules can check a user's role with a single read of this doc, and "my households" is `where memberIds array-contains uid`.

### `households/{householdId}/members/{uid}`

A member's name in this household. The doc ID is the member's uid. It is deleted when they leave.

| Field | Type | Notes |
|---|---|---|
| `name` | string | 1 to 100 characters |
| `inviteId` | string? | the invite most recently used to join; absent for the creator |
| `createdAt`, `updatedAt` | server timestamp | |
| `schemaVersion` | int | |

### `invites/{inviteId}`

`inviteId` is the SHA-256 hash (hex) of the code. Top-level, so the person joining can look it up before they can read the household.

| Field | Type | Notes |
|---|---|---|
| `householdId` | string | |
| `createdBy` | uid | the admin who made it |
| `createdAt` | server timestamp | the invite expires 7 days later; rules compute this, so no expiry is stored |
| `schemaVersion` | int | |

Making a new code deletes the household's old invite and creates the new one in one batch.

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

- **Household doc:** read if in `memberIds`; update if in `adminIds`; delete if the owner. Rules keep `adminIds` a non-empty subset of `memberIds`. A new household's `ownerId` must be its creator. An update can't remove it or take the owner out of `adminIds`; only the owner can change it, to someone already in `memberIds`, who must be in `adminIds` after the update, as must the old owner. A non-admin can make two changes only: add their own uid to `memberIds` when joining, and remove it when leaving. An admin who isn't the owner leaves through the admin update, removing their uid from both `memberIds` and `adminIds`.
- **Joining:** one batch adds the caller's uid to `memberIds` and creates their `members/{uid}` doc with `inviteId`. A doc kept from someone who left before leaving deleted it can't be read before joining, so when creating it is refused the app merges into it instead, keeping its `createdAt`. The household rule uses `getAfter` on that member doc to find the invite, and checks that it exists, points at this household and is less than 7 days old.
- **Members:** read if in `memberIds`. A member can create and update only their own doc, and only while their uid is in `memberIds` (checked with `getAfter`, so it can be in the same batch as creating or joining the household). A member can delete only their own doc, and only in the batch that removes them from `memberIds` (checked with `get` and `getAfter`). The owner can delete anyone's, only in the batch that deletes the household (checked with `existsAfter`).
- **Invites:** any signed-in user can `get` an invite by its ID; only the household's admins can list them (to see the active one's expiry) and create or delete them. An invite's ID must be a SHA-256 hex hash. An expired invite's ID can be reused by any household's admin.
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
- **Indexes:** the main query (a pet's logs by `occurredAt` descending) needs no custom index. Filtering by symptom needs a composite index on `(symptom, occurredAt)`. The home screen's recent logs, "Logged before" titles and last-logged pet all come from each pet's latest 50 logs by `occurredAt`, so they need no composite index either.
