import 'package:cloud_firestore/cloud_firestore.dart';

import 'pet.dart';

class PetRepository {
  PetRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _pets(String householdId) =>
      _firestore.collection('households').doc(householdId).collection('pets');

  /// The household's pets that aren't archived, sorted by name.
  ///
  /// Archived pets are filtered here rather than in the query: new pets have
  /// no `archivedAt` field, and Firestore's null filter doesn't match a
  /// missing field.
  Stream<List<Pet>> watchPets(String householdId) {
    return _pets(householdId).snapshots().map((snapshot) {
      final pets = snapshot.docs.map(Pet.fromFirestore).where((pet) => !pet.archived).toList();
      pets.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return pets;
    });
  }

  Future<void> addPet({
    required String householdId,
    required String name,
    required Species species,
    String? breed,
    DateTime? birthDate,
    Sex? sex,
  }) {
    return _pets(householdId).add(
      Pet.toFirestore(name: name, species: species, breed: breed, birthDate: birthDate, sex: sex),
    );
  }

  Future<void> updatePet({
    required String householdId,
    required String petId,
    required String name,
    required Species species,
    String? breed,
    DateTime? birthDate,
    Sex? sex,
  }) {
    return _pets(householdId)
        .doc(petId)
        .update(
          Pet.toFirestoreUpdate(
            name: name,
            species: species,
            breed: breed,
            birthDate: birthDate,
            sex: sex,
          ),
        );
  }
}
