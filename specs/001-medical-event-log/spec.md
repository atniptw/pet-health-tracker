# Feature Specification: Medical Event Log

**Feature Branch**: `rebuild-specs`

**Created**: 2026-11-14

**Status**: Being implemented

**Input**: User description: "I was inspired to make this app because I wanted to be able to log when important medical events happens to my pets. Existing pet apps are a whole diary/social media knockoff thing. I want to make it easy to remember what things a vet would want to know. Also helps us with time between events to let a vet know how often. I wanted to make it easy for my spouse and mother in law to use since we all take turns watching the animals. I want to make it easy to let the vet know."

## Context

The app exists so a pet owner can tell a vet what happened, when, and how often. It is a medical record, not a diary or a social feed: it holds medical events and nothing else. The people using it may not be comfortable with apps, so every step is simple enough for anyone looking after the animals.

This spec covers logging events and seeing how often they happen. Sharing the log with other caregivers and telling the vet are the user's other two goals; each gets its own spec.

## Clarifications

### Session 2026-11-14

- Q: How should the app help the caregiver remember what a vet would want to know? → A: Only the event type is required; details can be added while logging or later.
- Q: Is signing in required before logging? → A: No. Using the app without signing in is fine; what signing in adds is decided in the sharing spec.
- Q: When a pet dies or is rehomed, what should happen to it in the app? → A: Archive: it leaves the logging list, its history stays viewable, and it can be restored.
- Q: With several pets, which pet should already be picked when logging? → A: The pet most recently logged for, clearly shown and changeable.
- Q: When the same thing happens to more than one pet, can it be logged for all of them at once? → A: No. Each event is logged for one pet; the caregiver logs it again for the other.
- Q: What can a caregiver do with an event type they typed in their own words that they no longer want in the list? → A: Remove it from the list; past events keep their type, and typing it again brings it back.
- Q: Should the history's frequency periods match the vet view's? → A: Yes: last 30 days, last 90 days, last 12 months or all time.

### Session 2026-11-17 (autonomous run)

- Q: In what order are the history summary's types listed? → A: The type whose newest event happened most recently first (assumed, D-021)
- Q: How are the history's durations rounded, and how do a gap under a minute and a whole-number average over 2 days read? → A: Rounded down; "0 minutes"; one decimal kept, as in "3.0 days" (assumed, D-022)

### Session 2026-11-22

- Q: On the Event screen, how is the event's type changed? → A: A "Type" dropdown showing the current type.
- Q: What happens after "Save" on the Event screen? → A: The screen closes and the pet history shows the changed event.
- Q: What does the Event screen look like? → A: A full screen with an app bar titled "Event".
- Q: Where does "Delete" sit on the Event screen? → A: A text button in the app bar.
- Q: FR-015 says archived pets aren't offered when editing an event, but can an archived pet's own events still be edited? → A: Yes: the Event screen keeps the event's own archived pet picked, and offers no other archived pet.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Log an event as it happens (Priority: P1)

A caregiver sees one of their pets have a medical event (for example, vomiting or a seizure). They open the app, pick the pet and what happened, and save it. The time is recorded as now unless they change it.

**Why this priority**: Capturing the event at the moment it happens is the reason the app exists. Everything else depends on events being recorded.

**Independent Test**: With one pet set up, log an event and confirm it appears with the right pet, event and time.

**Acceptance Scenarios**:

1. **Given** a caregiver with one pet, **When** they open the app and choose an event, **Then** it is saved for that pet at the current time without asking which pet.
2. **Given** a caregiver with several active pets, **When** they start logging, **Then** the pet they most recently logged for is already picked and clearly shown, and they can pick another before saving.
3. **Given** a caregiver with several active pets who has never logged an event, or whose last-logged pet is archived, **When** they start logging, **Then** no pet is picked and they choose one before saving.
4. **Given** an event that happened a while ago, **When** they log it, **Then** they can set the date and time it actually happened.
5. **Given** an event type that isn't in the list, **When** they log it, **Then** they can enter it in their own words, and it is offered in the list next time.
6. **Given** a caregiver logging an event, **When** they have chosen the event type, **Then** they can save straight away. The type is the only thing required.
7. **Given** an event type with details a vet usually asks about (for example, how long a seizure lasted), **When** the caregiver logs it, **Then** those details are offered as optional questions they can answer before saving or skip.
8. **Given** a saved event, **When** the caregiver opens it later, **Then** they can add or change its details and note.
9. **Given** an event type the caregiver entered in their own words, **When** they remove it from the list, **Then** it is no longer offered when logging, and past events of that type keep it and still count in the time between events.

---

### User Story 2 - See how often events happen (Priority: P2)

A caregiver looks at a pet's history to see each event, how long it has been since the same event last happened, and how often that event has been happening.

**Why this priority**: The time between events is what tells a vet how often something happens. It is the second thing the user asked for, and it needs events to exist first.

**Independent Test**: Log the same event for a pet several times at known times, then confirm the history shows the right gaps and frequency.

**Acceptance Scenarios**:

1. **Given** a pet with several events, **When** the caregiver opens that pet's history, **Then** events are listed newest first, each with its date and time.
2. **Given** a pet with two or more events of the same type, **When** the caregiver views the history, **Then** each of those events shows the time since the previous event of that type.
3. **Given** a pet with events of a type, **When** the caregiver views that type, **Then** they see how many times it happened and the average time between occurrences over the period they choose (last 30 days, last 90 days, last 12 months or all time, the same periods as the vet view in spec 003).
4. **Given** a pet with only one event of a type, **When** the caregiver views the history, **Then** no time between events is shown for that type, and no error is shown either.

---

### User Story 3 - Set up pets (Priority: P1)

A caregiver adds the pets they look after, with a name and species, so events can be logged for them. When a pet dies or is rehomed, they archive it.

**Why this priority**: Events can't be logged without a pet, so this ships together with Story 1.

**Independent Test**: Add a pet, then confirm it can be chosen when logging an event.

**Acceptance Scenarios**:

1. **Given** a caregiver with no pets, **When** they open the app, **Then** they are asked to add their first pet before anything else.
2. **Given** an existing pet, **When** the caregiver changes its name or species, **Then** its existing events keep belonging to it.
3. **Given** an active pet, **When** the caregiver archives it, **Then** it is no longer offered when logging, and its history can still be viewed from a list of archived pets.
4. **Given** an archived pet, **When** the caregiver restores it, **Then** it is offered when logging again, with its full history.

---

### User Story 4 - Correct mistakes (Priority: P2)

A caregiver who logged the wrong pet, event, time or details fixes the entry, or deletes it if it shouldn't exist.

**Why this priority**: Wrong entries mislead the vet, so they must be fixable. This is less urgent than logging itself.

**Independent Test**: Edit an event's time and confirm the time between events updates. Then delete an event and confirm it is gone.

**Acceptance Scenarios**:

1. **Given** a logged event, **When** the caregiver edits its pet, event type, time, details or note, **Then** the history and the time between events reflect the change.
2. **Given** a logged event, **When** the caregiver deletes it, **Then** they are asked to confirm first, and once deleted the event is gone from the history and from the frequency figures.

---

### Edge Cases

- **EC-01**: An event's time is set in the future: the app does not accept it.
- **EC-02**: Two events of the same type are logged for the same pet a few seconds apart: both are kept. The caregiver can delete one if it's a duplicate.
- **EC-03**: An event is logged with the phone offline: it is saved and shown at once.
- **EC-04**: A caregiver removes one of their own event types and later types it again: it is offered in the list again, and its new events count together with the old ones.
- **EC-05**: The same thing happens to two pets: the caregiver logs one event for each pet, separately.
- **EC-06**: The phone's time zone changes: events keep the moment they happened and are shown in the current local time.
- **EC-07**: A caregiver types an event in their own words that matches an existing type except for capitalization: it is treated as the existing type.
- **EC-08**: The caregiver archives their only active pet: the app behaves as if there are no pets and asks them to add one, and archived pets stay viewable.
- **EC-09**: One active pet is left after archiving the others: the app no longer asks which pet an event is for.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Caregivers MUST be able to add pets with a name and species, and edit them later.
- **FR-002**: Caregivers MUST be able to log a medical event for a pet by choosing an event type from a list of common pet medical events.
- **FR-003**: The time of an event MUST default to the moment it is logged and MUST be changeable to any earlier date and time.
- **FR-004**: Caregivers MUST be able to log an event type that isn't in the list by entering it in their own words. Those types MUST be offered in the list for later events, and the caregiver MUST be able to remove them from the list. Removing a type MUST NOT change past events, and entering it again MUST offer it again.
- **FR-005**: The event type MUST be the only thing a caregiver has to enter to save an event. Everything else is optional.
- **FR-006**: Event types MUST be able to carry the details a vet usually asks about. While logging, the app offers them as optional questions alongside an optional free-text note, and the caregiver can add or change them at any time after saving.
- **FR-007**: With only one active pet, the app MUST NOT ask which pet an event is for. With several, the pet most recently logged for MUST be picked by default, clearly shown and changeable; if that pet is archived or nothing has been logged yet, no pet is picked.
- **FR-008**: Each pet MUST have a history listing its events newest first, with date, time, event type, details and note.
- **FR-009**: For each event, the history MUST show the time since the previous event of the same type for the same pet.
- **FR-010**: For each event type a pet has had, the app MUST show the count and the average time between occurrences over a chosen period: last 30 days, last 90 days, last 12 months or all time, defaulting to the last 90 days. These MUST be the same periods the vet view offers (spec 003).
- **FR-011**: Caregivers MUST be able to edit any part of a logged event and delete an event after confirming.
- **FR-012**: Logging MUST work without a network connection, and entries MUST NOT be lost.
- **FR-013**: The app MUST hold only medical events and pets: no photos feed, no social features and no general diary entries.
- **FR-014**: Everything in this spec MUST work without signing in. Events logged before a caregiver signs in MUST be kept when they do sign in.
- **FR-015**: Caregivers MUST be able to archive a pet and restore it later. Archived pets MUST NOT be offered when logging an event or as the pet to move an event to; an archived pet's own events stay editable, with that pet still picked. Their history MUST stay viewable.

### Key Entities

- **Pet**: An animal the caregiver looks after. It has a name and species, is either active or archived, and has many events.
- **Event type**: A kind of medical event, such as vomiting or a seizure. It is either from the built-in list or entered by a caregiver in their own words, and may come with details a vet usually asks about.
- **Event**: One occurrence of an event type for exactly one pet; an event is never shared between pets. It has the moment it happened, any details and an optional note.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A caregiver can log a common event for the current time in under 10 seconds from opening the app, and in no more than 3 taps when the right pet is already picked, whether it is the only pet or the one most recently logged for.
- **SC-002**: A first-time user who is not comfortable with apps can log their first event without help.
- **SC-003**: For any event type a pet has had at least twice, a caregiver can find how long it has been since the last one and how often it happens in under 15 seconds.
- **SC-004**: No logged event is lost on the phone it was logged on, including events logged offline, and none is lost when its caregiver signs in.

## Assumptions

- The built-in list covers events commonly reported to vets, such as vomiting, diarrhea, seizure, coughing, sneezing, limping, not eating, lethargy, scratching, accidents in the house and wounds. The plan sets the exact list.
- Species is chosen from common pet species, with an "other" option.
- Events are moments, not durations. Where duration matters (for example, how long a seizure lasted), it is recorded as one of the event's details.
- Signing in, what it adds and how it works are decided in the sharing spec. Until a caregiver signs in, their records live only on their phone.
- This spec covers one caregiver logging for their own pets. Shared logging between caregivers and telling the vet are separate specs.
