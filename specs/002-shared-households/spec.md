# Feature Specification: Shared Households

**Feature Branch**: `rebuild-specs`

**Created**: 2026-11-14

**Status**: Draft

**Input**: User description: "Would use households. Each person in the house hold gets to see the data. Means we have to work out user permission levels"

## Context

The people who look after the pets take turns, for example a couple and a parent, and each of them needs to log events and see what the others logged. A household is the group of people who share a set of pets and their medical events. This spec adds households, joining one, and what each member is allowed to do. It builds on the medical event log (spec 001), which works on one phone without signing in.

## Clarifications

### Session 2026-11-14

- Q: Can one person belong to several households at once? → A: Yes, one or more.
- Q: Which permission levels exist, and what can each do? → A: Three levels: Owner, Admin and Member. Members log, edit and delete any event and add, edit and archive pets. Admins can also invite, cancel invites, remove members and rename the household. The one Owner can also change levels, remove admins, delete the household and hand ownership to another member.
- Q: How does someone join a household? → A: In person only: the new person scans a code shown on the inviter's phone.
- Q: When someone deletes their account, what should the household see as "logged by" on their events? → A: "Former member" in place of their name; the events stay.
- Q: When one member edits an event someone else logged, should the history show who changed it? → A: Yes: who last edited it, and when, next to "logged by".
- Q: Which ways of signing in should the app offer? → A: Google on both platforms and Apple on iOS.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Start sharing my pets (Priority: P1)

A caregiver who has been logging on their own phone decides to share with the people they live with. They sign in, and a household is created that holds the pets and events they already logged.

**Why this priority**: Nobody can share until a household exists, and no existing record may be lost when it is created.

**Independent Test**: Log events without signing in, sign in, then confirm every pet and event is in the new household, with nothing lost or duplicated.

**Acceptance Scenarios**:

1. **Given** a caregiver with pets and events and no account, **When** they sign in for the first time, **Then** a household is created for them, holding all their pets and events.
2. **Given** a caregiver with no pets and no account, **When** they sign in, **Then** a household is created for them, empty and ready for pets.
3. **Given** a household, **When** its owner looks at it, **Then** it has a name they can change.

---

### User Story 2 - Bring someone into the household (Priority: P1)

An admin or the owner invites someone, such as their spouse, in person: they show a code on their phone, and the other person installs the app, signs in and scans it. That person joins and sees the household's pets and events.

**Why this priority**: Sharing with the people who take turns watching the animals is the point of this spec.

**Independent Test**: Invite a second person, have them join on their own phone, then confirm both see the same pets and events.

**Acceptance Scenarios**:

1. **Given** an admin or the owner, **When** they create an invite, **Then** their phone shows a code, and a signed-in person who scans it with the app joins the household as a Member straight away.
2. **Given** someone who joined, **When** they open the app, **Then** they see all of the household's pets and events, including everything logged before they joined.
3. **Given** an invite that has been used, cancelled or has expired, **When** someone tries to join with it, **Then** they can't, and they are told why.
4. **Given** someone joining who has already logged pets and events on their own phone, **When** they join, **Then** they choose whether to bring those pets and events into the household they are joining or keep them in a household of their own.

---

### User Story 3 - Everyone sees and logs the same record (Priority: P1)

Members log events for the household's pets, and every member sees each other's events, with who logged each one.

**Why this priority**: Shared visibility is what the user asked for: whoever is watching the animals can see what happened while someone else was.

**Independent Test**: Have two members log events for the same pet on two phones, then confirm both phones show both events, each marked with who logged it.

**Acceptance Scenarios**:

1. **Given** two members on different phones, **When** one logs an event, **Then** the other sees it, marked with who logged it, as soon as both phones are online.
2. **Given** a member who logs an event offline, **When** their phone is back online, **Then** the other members see the event with the time it happened, not the time it was sent.
3. **Given** an event one member logged, **When** another member edits it, **Then** everyone sees who last edited it, and when, next to who logged it.
4. **Given** two members, **When** each views a pet's time between events, **Then** it is worked out from everyone's events together.

---

### User Story 4 - Decide what each person can do (Priority: P1)

Each member is the Owner, an Admin or a Member. A parent who helps out, for example, can be a Member who logs events without being able to remove people or delete the household.

**Why this priority**: The user named permission levels as the part that must be worked out before households can be shared safely.

**Independent Test**: Give two members different levels, then confirm each one can do exactly what their level allows and is stopped from everything else.

**Acceptance Scenarios**:

1. **Given** members with different levels, **When** each tries an action, **Then** they can do exactly what their level allows, as set out in FR-009.
2. **Given** the owner, **When** they make a Member an Admin or an Admin a Member, **Then** that person's level changes at once.
3. **Given** the owner, **When** they hand ownership to another member and confirm, **Then** that member becomes the Owner and the former owner becomes an Admin.
4. **Given** a member who is not allowed an action, **When** they look for it, **Then** it is not offered to them.
5. **Given** a household, **When** its members are listed, **Then** each member's name and level are shown.

---

### User Story 5 - Leave or end a household (Priority: P2)

A member who no longer looks after the pets leaves the household, or is removed from it. When a household is no longer needed, it is deleted.

**Why this priority**: People move out and families change. This is less urgent than joining and sharing.

**Independent Test**: Remove a member, then confirm they no longer see the household's pets and events, and that the events they logged remain for everyone else.

**Acceptance Scenarios**:

1. **Given** a member, **When** they leave the household, **Then** they no longer see its pets and events, and the events they logged stay in the household, still marked with their name.
2. **Given** an admin, **When** they remove a Member, **Then** that person loses access at once. Only the owner can remove an Admin, and nobody can remove the owner.
3. **Given** a household, **When** the owner deletes it and confirms, **Then** the household, its pets and its events are removed for every member.
4. **Given** the owner, **When** they try to leave, **Then** they must first hand ownership to another member or delete the household, so a household always has exactly one owner.

---

### User Story 6 - Delete my account (Priority: P2)

A person who no longer wants to use the app deletes their account.

**Why this priority**: The app stores must let people who create an account delete it.

**Independent Test**: Delete an account, then confirm the person can no longer sign in to it, and that the households they shared are handled as in Story 5.

**Acceptance Scenarios**:

1. **Given** a signed-in person, **When** they delete their account and confirm, **Then** they leave every household they belong to, as in Story 5, and their account is removed. The events they logged stay, shown as logged by "Former member" instead of their name.
2. **Given** a person who owns a household, **When** they delete their account, **Then** they must first hand ownership of that household to another member or delete it.

---

### Edge Cases

- Two members edit the same event at nearly the same time: the last change saved wins, and nobody's phone shows a different version once both are online.
- A member is removed while their phone is offline with unsent events: those events are not added to the household once the phone comes back online, and the person is told they no longer belong to it.
- A member archives a pet: it is archived for everyone in the household.
- A member removes one of the household's own event types from the list: it is removed for everyone, and past events keep it.
- Someone signs in on a second phone: they see the same households, pets and events as on their first.
- A person belongs to two households: each one's pets, events and event types are shown only while that household is the one they are in.
- A person leaves or is removed from their only household: they are asked to create a new household or join one.
- A person is invited to a household while already in one: they join it as well, and keep their existing household.
- A member signs out: the household's pets and events are no longer shown on that phone.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: People MUST be able to sign in with Google on iOS and Android, and with Apple on iOS. No other sign-in methods are offered. Signing in is needed only to share; logging on one phone works without it (spec 001).
- **FR-002**: Signing in for the first time MUST create a household with the person as its Owner, holding every pet and event they logged on that phone without an account, unless they are signing in to join a household. A person who joins with pets and events on their phone MUST choose to bring them into the household they join or keep them in a household of their own.
- **FR-003**: Each household MUST have a name, which an admin or the owner can change.
- **FR-004**: Admins and the owner MUST be able to invite people in person only: their phone shows a code, and the person joining scans it with the app while signed in. They join as a Member straight away. Each code MUST work once, MUST expire if unused, and MUST be cancellable by any admin or the owner. Invites MUST NOT be possible by sending a link or code from a distance.
- **FR-005**: Every member MUST see all of the household's pets and events, including those logged before they joined.
- **FR-006**: Each event MUST record which member logged it, and the history MUST show that member's name. Once an event has been edited, it MUST also record and show who last edited it and when.
- **FR-007**: Events logged by any member MUST reach the other members' phones without anyone having to refresh, as soon as both phones are online.
- **FR-008**: Time between events and frequency (spec 001) MUST be worked out from every member's events together.
- **FR-009**: Each member MUST have one of three permission levels, and the app MUST allow only the actions their level permits:
  - **Member**: see everything in the household; log, edit and delete any event; add, edit, archive and restore pets; remove the household's own event types from the list; leave the household.
  - **Admin**: everything a Member can do, plus invite people, cancel invites, remove Members and rename the household.
  - **Owner**: everything an Admin can do, plus make Members Admins and Admins Members, remove Admins, hand ownership to another member and delete the household. Each household has exactly one owner.
- **FR-010**: Actions a member is not allowed MUST NOT be offered to them, and MUST be refused even if attempted another way.
- **FR-011**: Members MUST be able to see the list of members, with each one's name and permission level.
- **FR-012**: Each member MUST have a name the other members see, which they choose and can change.
- **FR-013**: Members and admins MUST be able to leave a household. Admins MUST be able to remove Members, and the owner MUST be able to remove anyone except themself. A member who leaves or is removed MUST lose access at once, and the events they logged MUST stay, still marked with their name.
- **FR-014**: A household MUST always have exactly one owner. The owner can't leave or delete their account until they hand ownership to another member or delete the household. A member who is handed ownership becomes the Owner and the former owner becomes an Admin.
- **FR-015**: The owner MUST be able to delete the household, after confirming. Deleting it removes its pets and events for every member.
- **FR-016**: People MUST be able to delete their account from within the app. The events they logged MUST stay in their households, and their name MUST be replaced by "Former member" everywhere it was shown, including as the last editor.
- **FR-017**: Only members of a household MUST be able to see or change its pets and events.
- **FR-018**: A person MUST be able to belong to one or more households at once, each kept separate. They MUST be able to switch between them, and the app MUST always show which household they are in. Logging, history and frequency apply to the household they are in.
- **FR-019**: Pets, events, archiving and the event-type list from spec 001 MUST be shared by the household: a change by one member applies for every member.

### Key Entities

- **Person**: Someone who has signed in. They have a display name and belong to one or more households.
- **Household**: A group of people who share pets. It has a name, members, pets and its own event types.
- **Membership**: A person's place in a household, with their permission level: Owner, Admin or Member.
- **Invite**: A one-time code shown on an admin's or the owner's phone and scanned in person. It is either pending, used, cancelled or expired.
- **Pet, Event, Event type** (spec 001): These now belong to a household. Each event also records which member logged it and, once edited, who last edited it and when.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A person standing next to an admin can install the app, sign in, scan the code and see the household's pets in under 3 minutes, without help.
- **SC-002**: An event logged by one member appears on another member's online phone within 10 seconds.
- **SC-003**: Nobody who is not a member of a household can see or change its pets or events.
- **SC-004**: No pet or event logged before signing in is lost or duplicated when its caregiver signs in or joins a household.
- **SC-005**: A member can find who logged any event, and when, in under 5 seconds from that pet's history.

## Assumptions

- Households are small, around 2 to 10 members.
- An invite code that isn't used expires after 15 minutes, since both people are in the same place.
- Account deletion is required by the app stores for any app where people create an account.
- Telling the vet is a separate spec.
