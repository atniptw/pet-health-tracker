import '../domain/event_type.dart';
import '../domain/medical_event.dart';
import '../domain/pet.dart';

/// Reads and changes the caregiver's pets.
abstract interface class PetRepository {
  /// Pets not archived, by name.
  Stream<List<Pet>> watchActive();

  /// Archived pets, by name.
  Stream<List<Pet>> watchArchived();

  /// The pet with [id], or null if there is none.
  Stream<Pet?> watch(String id);

  /// Throws [ArgumentError] for a name that is empty after trimming or over
  /// 40 characters.
  Future<Pet> add({required String name, required Species species});

  /// Throws [ArgumentError] for a name that is empty after trimming or over
  /// 40 characters.
  Future<void> update(String id, {required String name, required Species species});

  Future<void> setArchived(String id, bool archived);
}

/// Reads and removes event types; new custom types are created by
/// [EventRepository.log] and [EventRepository.update].
abstract interface class EventTypeRepository {
  /// Built-in types in their order, then custom types not removed, by name.
  Stream<List<EventType>> watchOffered();

  /// Custom types not removed, by name.
  Stream<List<EventType>> watchCustom();

  /// Any type, including removed custom ones.
  Future<EventType> byId(String id);

  /// The type whose name matches [typed] by [matchKey], among the last loaded
  /// types; null if the name is new.
  EventType? match(String typed);

  /// Removes a custom type from the list; past events keep it.
  Future<void> remove(String customId);
}

/// The event type the caregiver picked.
sealed class TypeChoice {}

/// A type that already exists.
final class ExistingType extends TypeChoice {
  ExistingType(this.typeId);

  final String typeId;

  @override
  bool operator ==(Object other) => other is ExistingType && other.typeId == typeId;

  @override
  int get hashCode => typeId.hashCode;
}

/// A name the caregiver typed, saved as a new custom type unless it matches
/// an existing one.
final class NewTypeName extends TypeChoice {
  NewTypeName(this.name);

  final String name;

  @override
  bool operator ==(Object other) => other is NewTypeName && other.name == name;

  @override
  int get hashCode => name.hashCode;
}

/// Reads and changes medical events.
abstract interface class EventRepository {
  /// The pet's events, newest first.
  Stream<List<MedicalEvent>> watchForPet(String petId);

  /// The event with [id], or null if there is none.
  Stream<MedicalEvent?> watch(String id);

  /// Writes the event, any new or un-removed custom type and the last logged
  /// pet in one transaction.
  ///
  /// Throws [ArgumentError] when [occurredAt] is after now, the pet is
  /// archived, a detail key isn't one of the type's questions, or a value
  /// doesn't fit its question.
  Future<MedicalEvent> log({
    required String petId,
    required TypeChoice type,
    required DateTime occurredAt,
    Map<String, Object> details = const {},
    String? note,
  });

  /// Throws [ArgumentError] as [log] does, except that an archived pet is
  /// allowed when it is the event's current pet.
  Future<void> update(
    String id, {
    required String petId,
    required TypeChoice type,
    required DateTime occurredAt,
    required Map<String, Object> details,
    String? note,
  });

  Future<void> delete(String id);

  /// The pet most recently logged for, or null if none has been.
  Future<String?> lastLoggedPetId();
}

/// The current time: `DateTime.now` in the app, fixed in tests.
typedef Clock = DateTime Function();

/// A new unique id: a random UUID in the app, sequential in tests.
typedef IdGenerator = String Function();
