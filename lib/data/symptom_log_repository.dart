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
}
