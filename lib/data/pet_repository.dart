import 'package:cloud_firestore/cloud_firestore.dart';

import 'pet.dart';

class PetRepository {
  PetRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _pets(String householdId) =>
      _firestore.collection('households').doc(householdId).collection('pets');

  /// The household's pets that aren't archived, sorted by name.
  Stream<List<Pet>> watchPets(String householdId) => _watch(householdId, archived: false);

  /// The household's archived pets, sorted by name.
  Stream<List<Pet>> watchArchivedPets(String householdId) => _watch(householdId, archived: true);

  /// Filters on `archived` here rather than in the query: a pet that isn't
  /// archived has no `archivedAt` field, and Firestore's null filter doesn't
  /// match a missing field.
  Stream<List<Pet>> _watch(String householdId, {required bool archived}) {
    return _pets(householdId).snapshots().map((snapshot) {
      final pets = snapshot.docs
          .map(Pet.fromFirestore)
          .where((pet) => pet.archived == archived)
          .toList();
      pets.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return pets;
    });
  }

  /// Archives the pet, so it leaves the household's pets and their recent
  /// logs, and keeps its history. The rules allow this only for admins.
  Future<void> archivePet({required String householdId, required String petId}) {
    return _pets(householdId).doc(petId).update({
      'archivedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Brings an archived pet back to the household's pets. The rules allow
  /// this only for admins.
  Future<void> unarchivePet({required String householdId, required String petId}) {
    return _pets(householdId)
        .doc(petId)
        .update({'archivedAt': FieldValue.delete(), 'updatedAt': FieldValue.serverTimestamp()});
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
