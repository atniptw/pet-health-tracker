# Feature Specification: Vet View

**Feature Branch**: `rebuild-specs`

**Created**: 2026-11-14

**Status**: Draft

**Input**: User description: "For the vet I don't want anything fancy. A chart or calendar so they can get a sense. I'd just hand them my phone"

## Context

At the vet, the caregiver opens a pet's events in a simple picture of when they happened and hands the vet their phone. The vet gets a sense of what happened and how often in a few seconds, without reading through a list. Nothing is sent, printed or exported. Handing over the phone is the whole flow. This spec builds on the medical event log (spec 001) and, for households, on shared households (spec 002).

## Clarifications

### Session 2026-11-14

- Q: Should the vet view be a chart, a calendar, or both? → A: A timeline chart: one row per event type, with a dot for each event along a time axis.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Show the vet a pet's events over time (Priority: P1)

In the exam room, the caregiver opens the vet view for a pet and hands the vet their phone. The vet sees the pet's events laid out over time and can tell at a glance when things happened, how often, and whether they're getting more or less frequent.

**Why this priority**: This is the whole feature: letting the vet get a sense of the pet's events from the caregiver's phone.

**Independent Test**: Log events of two types for a pet across several weeks, open the vet view, and confirm someone who has never used the app can say when each type happened and roughly how often.

**Acceptance Scenarios**:

1. **Given** a pet with events, **When** the caregiver opens the vet view for that pet, **Then** its events are shown on a timeline chart: one row per event type, with a dot for each event along a time axis covering the chosen period.
2. **Given** a pet with events of several types, **When** the vet view is shown, **Then** each event type is told apart clearly, for example by color with a label, and not by color alone.
3. **Given** the vet view, **When** the vet picks a period (last 30 days, last 90 days, last 12 months or all time), **Then** only events in that period are shown.
4. **Given** a pet with no events in the chosen period, **When** the vet view is shown, **Then** it says there are no events in that period.

---

### User Story 2 - Look closer at one event (Priority: P2)

The vet sees something on the picture and wants to know more about it, such as what a vomit looked like or how long a seizure lasted. They tap it and see that event's details and note.

**Why this priority**: The picture gives the vet a sense of things, and the details answer their next question. It's less essential than the picture itself.

**Independent Test**: Log an event with details and a note, then tap it in the vet view and confirm the details, note and exact time are shown.

**Acceptance Scenarios**:

1. **Given** the vet view, **When** the vet taps a dot or a cluster of dots, **Then** they see each event there with its type, exact date and time, details and note.
2. **Given** the vet looking at an event's details, **When** they go back, **Then** they return to the same picture and period they were looking at.

---

### User Story 3 - Hand over the phone without worry (Priority: P2)

The caregiver hands their phone to the vet knowing the vet can look but can't change or delete anything by accident.

**Why this priority**: The caregiver is handing over their phone, so the vet view mustn't let anyone alter the record or wander elsewhere by accident.

**Independent Test**: Open the vet view and confirm nothing on it lets you edit, delete or log an event, or switch to another pet or household.

**Acceptance Scenarios**:

1. **Given** the vet view, **When** the vet uses it, **Then** nothing on it edits, deletes or adds events.
2. **Given** the vet view for a pet, **When** the vet uses it, **Then** it shows only that pet, and leaving it takes a deliberate step back to the rest of the app.

---

### Edge Cases

- A pet has hundreds of events in the chosen period: the picture still shows how often they happen, without becoming unreadable.
- Several events of one type happen close together: their dots stay distinguishable or are shown as a cluster with a count, and tapping it lists them all.
- A pet has only one event: it is shown, and no frequency is suggested.
- The phone is turned sideways: the picture uses the extra width.
- An archived pet: its vet view can still be opened from its history.
- The phone is offline in the exam room: the vet view shows everything already on the phone.
- A household member logs an event while the vet is looking: it can appear, and it never interrupts or resets what the vet is looking at.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Caregivers MUST be able to open a vet view for any pet, active or archived, from that pet in the app.
- **FR-002**: The vet view MUST show the pet's events on a timeline chart: one row per event type, labelled with the type, with a dot for each event at the moment it happened along a time axis covering the chosen period, so a viewer can tell when each event type happened and how often.
- **FR-003**: Event types MUST be told apart by a label as well as by color, and a legend MUST name each type shown.
- **FR-004**: The vet view MUST let the viewer pick the period shown (last 30 days, last 90 days, last 12 months or all time), defaulting to the last 90 days.
- **FR-005**: For each event type shown, the vet view MUST show its count and the average time between occurrences in the period, as worked out in spec 001.
- **FR-006**: Tapping a dot or a cluster of dots MUST show each event there with its type, exact date and time, details and note.
- **FR-007**: The vet view MUST be read-only: it MUST NOT offer any way to log, edit or delete events, or to change pets, households or settings.
- **FR-008**: The vet view MUST show the pet's name at all times, and MUST show only that pet.
- **FR-009**: The vet view MUST work offline with everything already on the phone.
- **FR-010**: The vet view MUST NOT offer sending, sharing, printing or exporting. Showing the phone is the only way the vet sees the record.

### Key Entities

- No new entities. The vet view shows the pets, events and event types from spec 001.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Someone who has never used the app, handed the phone on the vet view, can say which event types happened and roughly how often within 30 seconds, without explanation.
- **SC-002**: A caregiver can go from opening the app to handing over the vet view for a pet in under 10 seconds.
- **SC-003**: Nobody using only the vet view can change, add or delete an event.
- **SC-004**: The vet view stays readable with up to 500 events in the chosen period.

## Assumptions

- The vet looks at the caregiver's phone in person, held upright or turned sideways.
- The vet view shows one pet at a time, since a vet visit is about one animal.
- Reading the view takes no medical knowledge from the app: it shows what was logged and doesn't diagnose or advise.
