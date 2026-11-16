import 'package:characters/characters.dart';

import 'event_type.dart';

/// One occurrence of an event type for one pet.
class MedicalEvent {
  const MedicalEvent({
    required this.id,
    required this.petId,
    required this.typeId,
    required this.occurredAt,
    this.details = const {},
    this.note,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String petId;
  final String typeId;

  /// When it happened, in UTC.
  final DateTime occurredAt;

  /// Answers keyed by the type's question ids.
  final Map<String, Object> details;

  final String? note;

  /// When it was logged, in UTC.
  final DateTime createdAt;

  /// When it was logged or last edited, in UTC.
  final DateTime updatedAt;

  @override
  bool operator ==(Object other) =>
      other is MedicalEvent &&
      other.id == id &&
      other.petId == petId &&
      other.typeId == typeId &&
      other.occurredAt == occurredAt &&
      _mapEquals(other.details, details) &&
      other.note == note &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hash(
    id,
    petId,
    typeId,
    occurredAt,
    Object.hashAllUnordered(details.entries.map((e) => Object.hash(e.key, e.value))),
    note,
    createdAt,
    updatedAt,
  );
}

/// The longest note, in user-perceived characters.
const _maxNoteLength = 1000;

/// [details] unchanged; throws [ArgumentError] unless every key is one of
/// [type]'s question ids and its question accepts the answer.
Map<String, Object> validDetails(EventType type, Map<String, Object> details) {
  for (final MapEntry(:key, :value) in details.entries) {
    final question = _question(type, key);
    if (question == null) {
      throw ArgumentError('A key is not one of the type\'s questions', 'details');
    }
    if (!question.accepts(value)) {
      throw ArgumentError('An answer does not fit its question', 'details');
    }
  }
  return details;
}

/// [note] trimmed, or null when empty; throws [ArgumentError] when over 1000
/// characters.
String? validNote(String? note) {
  final trimmed = note?.trim() ?? '';
  if (trimmed.isEmpty) return null;
  if (trimmed.characters.length > _maxNoteLength) {
    throw ArgumentError('Must be at most $_maxNoteLength characters', 'note');
  }
  return trimmed;
}

/// The [details] whose question ids [newType] also has.
Map<String, Object> detailsKeptFor(EventType newType, Map<String, Object> details) => {
  for (final MapEntry(:key, :value) in details.entries)
    if (_question(newType, key) != null) key: value,
};

DetailQuestion? _question(EventType type, String id) {
  for (final question in type.questions) {
    if (question.id == id) return question;
  }
  return null;
}

bool _mapEquals(Map<String, Object> a, Map<String, Object> b) {
  if (a.length != b.length) return false;
  for (final MapEntry(:key, :value) in a.entries) {
    if (!b.containsKey(key) || b[key] != value) return false;
  }
  return true;
}
