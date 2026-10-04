import 'package:cloud_firestore/cloud_firestore.dart';

enum Species {
  dog('Dog'),
  cat('Cat'),
  other('Other');

  const Species(this.label);

  final String label;
}

enum Sex {
  female('Female'),
  male('Male'),
  unknown('Unknown');

  const Sex(this.label);

  final String label;
}

class Pet {
  const Pet({
    required this.id,
    required this.name,
    required this.species,
    this.breed,
    this.birthDate,
    this.sex,
    this.archived = false,
  });

  final String id;
  final String name;
  final Species species;
  final String? breed;

  /// A calendar date with no time of day.
  final DateTime? birthDate;
  final Sex? sex;
  final bool archived;

  /// Values written by a newer app version that this one doesn't know are
  /// read as [Species.other] or left unset, rather than failing.
  factory Pet.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return Pet(
      id: doc.id,
      name: data['name'] as String,
      species: Species.values.asNameMap()[data['species']] ?? Species.other,
      breed: data['breed'] as String?,
      birthDate: _parseDate(data['birthDate'] as String?),
      sex: Sex.values.asNameMap()[data['sex']],
      archived: data['archivedAt'] != null,
    );
  }

  /// Optional fields are left out when unset, as the security rules expect.
  static Map<String, dynamic> toFirestore({
    required String name,
    required Species species,
    String? breed,
    DateTime? birthDate,
    Sex? sex,
  }) {
    return {
      'name': name,
      'species': species.name,
      if (breed != null && breed.isNotEmpty) 'breed': breed,
      if (birthDate != null) 'birthDate': _formatDate(birthDate),
      if (sex != null) 'sex': sex.name,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'schemaVersion': 1,
    };
  }

  static final _datePattern = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

  static DateTime? _parseDate(String? value) {
    final match = value == null ? null : _datePattern.firstMatch(value);
    if (match == null) return null;
    return DateTime(int.parse(match[1]!), int.parse(match[2]!), int.parse(match[3]!));
  }

  static String _formatDate(DateTime date) {
    String pad(int n, int width) => n.toString().padLeft(width, '0');
    return '${pad(date.year, 4)}-${pad(date.month, 2)}-${pad(date.day, 2)}';
  }
}
