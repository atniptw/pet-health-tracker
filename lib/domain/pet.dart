import 'package:characters/characters.dart';

/// The species a caregiver can choose for a pet (research §6).
enum Species {
  dog('dog', 'Dog'),
  cat('cat', 'Cat'),
  other('other', 'Other');

  const Species(this.id, this.label);

  /// The stored id, which never changes.
  final String id;

  /// The name shown to the caregiver.
  final String label;

  /// The species with [id]; throws [ArgumentError] for an unknown id.
  static Species fromId(String id) {
    for (final species in values) {
      if (species.id == id) return species;
    }
    throw ArgumentError.value(id, 'id', 'Unknown species');
  }
}

/// An animal the caregiver looks after.
class Pet {
  const Pet({
    required this.id,
    required this.name,
    required this.species,
    this.archived = false,
    required this.createdAt,
  });

  final String id;
  final String name;
  final Species species;
  final bool archived;

  /// When the pet was added, in UTC.
  final DateTime createdAt;

  Pet copyWith({String? id, String? name, Species? species, bool? archived, DateTime? createdAt}) {
    return Pet(
      id: id ?? this.id,
      name: name ?? this.name,
      species: species ?? this.species,
      archived: archived ?? this.archived,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Pet &&
      other.id == id &&
      other.name == name &&
      other.species == species &&
      other.archived == archived &&
      other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(id, name, species, archived, createdAt);
}

/// The longest pet name, in user-perceived characters.
const _maxPetNameLength = 40;

/// [name] trimmed; throws [ArgumentError] unless it is 1–40 characters.
String validPetName(String name) {
  final trimmed = name.trim();
  final length = trimmed.characters.length;
  if (length < 1 || length > _maxPetNameLength) {
    throw ArgumentError('Must be 1–$_maxPetNameLength characters', 'name');
  }
  return trimmed;
}
