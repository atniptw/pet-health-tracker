# Contract: Repositories

The interfaces screens use to read and change records (`lib/data/repositories.dart`). The local SQLite implementations are in `lib/data/local/`. Types are those in `data-model.md`.

Every `watch…` stream emits the current value on listen and again after any write through the same repository object. Every write either completes fully or changes nothing (one SQLite transaction), and returns once it is on disk.

## PetRepository

```dart
abstract interface class PetRepository {
  Stream<List<Pet>> watchActive();            // by name
  Stream<List<Pet>> watchArchived();          // by name
  Stream<Pet?> watch(String id);
  Future<Pet> add({required String name, required Species species});
  Future<void> update(String id, {required String name, required Species species});
  Future<void> setArchived(String id, bool archived);
}
```

- `add` and `update` throw `ArgumentError` for a name that is empty after trimming or over 40 characters.

## EventTypeRepository

```dart
abstract interface class EventTypeRepository {
  Stream<List<EventType>> watchOffered();     // built-ins in order, then custom not removed, by name
  Stream<List<EventType>> watchCustom();      // custom not removed, by name, for "My event types"
  Future<EventType> byId(String id);          // any type, including removed custom ones
  EventType? match(String typed);             // research §7, against the last loaded types; null if new
  Future<void> remove(String customId);       // FR-004; past events keep the type
}
```

- `byId` resolves every `typeId` an event can hold, so the history always has a name to show.
- A new custom type is created by `EventRepository.log` / `update` with a `NewTypeName`, so a typed name that is never saved creates nothing.

## EventRepository

```dart
sealed class TypeChoice {}                    // what the caregiver picked
final class ExistingType extends TypeChoice { final String typeId; }
final class NewTypeName extends TypeChoice { final String name; }

abstract interface class EventRepository {
  Stream<List<MedicalEvent>> watchForPet(String petId);   // newest first
  Stream<MedicalEvent?> watch(String id);
  Future<MedicalEvent> log({
    required String petId,
    required TypeChoice type,
    required DateTime occurredAt,
    Map<String, Object> details = const {},
    String? note,
  });
  Future<void> update(String id, {
    required String petId,
    required TypeChoice type,
    required DateTime occurredAt,
    required Map<String, Object> details,
    String? note,
  });
  Future<void> delete(String id);
  Future<String?> lastLoggedPetId();
}
```

- `log` writes the event, any new or un-removed custom type, and `last_logged_pet_id` in one transaction (research §9).
- `log` and `update` throw `ArgumentError` when `occurredAt` is after now, the pet is archived (unless `update` keeps the event's current pet), a detail key isn't one of the type's questions, or a value doesn't fit its question.
- The event repository notifies the event type repository's streams when it creates or un-removes a type.

## Clock and ids

```dart
typedef Clock = DateTime Function();          // DateTime.now in the app, fixed in tests
typedef IdGenerator = String Function();      // UUID v4 in the app, sequential in tests
```

Repositories take both in their constructors so tests can fix the time and ids.
