import 'package:cloud_firestore/cloud_firestore.dart';

import 'symptom_log.dart';

class SymptomLogRepository {
  SymptomLogRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _logs(String householdId, String petId) => _firestore
      .collection('households')
      .doc(householdId)
      .collection('pets')
      .doc(petId)
      .collection('symptomLogs');

  /// The pet's logs, most recent first.
  Stream<List<SymptomLog>> watchLogs({required String householdId, required String petId}) {
    return _logs(householdId, petId)
        .orderBy('occurredAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(SymptomLog.fromFirestore).toList());
  }

  Future<void> addOtherLog({
    required String householdId,
    required String petId,
    required String createdBy,
    required String title,
    required DateTime occurredAt,
    String? notes,
  }) {
    return _logs(householdId, petId).add(
      SymptomLog.otherToFirestore(
        createdBy: createdBy,
        title: title,
        occurredAt: occurredAt,
        notes: notes,
      ),
    );
  }

  Future<void> updateOtherLog({
    required String householdId,
    required String petId,
    required String logId,
    required String title,
    required DateTime occurredAt,
    String? notes,
  }) {
    return _logs(householdId, petId)
        .doc(logId)
        .update(
          SymptomLog.otherToFirestoreUpdate(title: title, occurredAt: occurredAt, notes: notes),
        );
  }

  /// An id for a new log. Lets the caller refer to the log straight away,
  /// without waiting for the write to reach the server.
  String newLogId({required String householdId, required String petId}) {
    return _logs(householdId, petId).doc().id;
  }

  Future<void> addCatalogLog({
    required String householdId,
    required String petId,
    required String logId,
    required String createdBy,
    required String symptom,
    required DateTime occurredAt,
  }) {
    assert(symptom != SymptomLog.otherSymptom, 'other logs need a title: use addOtherLog');
    return _logs(householdId, petId)
        .doc(logId)
        .set(
          SymptomLog.catalogToFirestore(
            createdBy: createdBy,
            symptom: symptom,
            occurredAt: occurredAt,
          ),
        );
  }

  /// Writes only the [answers] given, keyed by question key, so answers this
  /// app doesn't know about are kept. A null answer is removed.
  Future<void> updateAnswers({
    required String householdId,
    required String petId,
    required String logId,
    required Map<String, Object?> answers,
  }) {
    return _logs(householdId, petId).doc(logId).update({
      for (final MapEntry(:key, :value) in answers.entries)
        FieldPath(['answers', key]): value ?? FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteLog({
    required String householdId,
    required String petId,
    required String logId,
  }) {
    return _logs(householdId, petId).doc(logId).delete();
  }
}
