import 'package:cloud_firestore/cloud_firestore.dart';

class SymptomLog {
  const SymptomLog({
    required this.id,
    required this.symptom,
    required this.createdBy,
    required this.occurredAt,
    this.title,
    this.answers = const {},
    this.notes,
  });

  /// The symptom key for a log that isn't from the catalog.
  static const otherSymptom = 'other';

  final String id;

  /// A catalog key such as `vomit`, or [otherSymptom].
  final String symptom;

  /// Set only when [symptom] is [otherSymptom]. Catalog symptoms take their
  /// title from the catalog.
  final String? title;

  /// The uid of the member who logged it.
  final String createdBy;

  /// Type-specific answers, keyed by question key.
  final Map<String, dynamic> answers;

  /// When it happened, in local time.
  final DateTime occurredAt;
  final String? notes;

  factory SymptomLog.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return SymptomLog(
      id: doc.id,
      symptom: data['symptom'] as String,
      title: data['title'] as String?,
      createdBy: data['createdBy'] as String,
      answers: (data['answers'] as Map<String, dynamic>?) ?? const {},
      occurredAt: (data['occurredAt'] as Timestamp).toDate(),
      notes: data['notes'] as String?,
    );
  }

  /// A new [otherSymptom] log. Optional fields are left out when unset, as the
  /// security rules expect.
  static Map<String, dynamic> otherToFirestore({
    required String createdBy,
    required String title,
    required DateTime occurredAt,
    String? notes,
  }) {
    return {
      'symptom': otherSymptom,
      'title': title,
      'createdBy': createdBy,
      'occurredAt': Timestamp.fromDate(occurredAt),
      if (notes != null && notes.isNotEmpty) 'notes': notes,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'schemaVersion': 1,
    };
  }

  /// A new catalog log, with no answers yet.
  static Map<String, dynamic> catalogToFirestore({
    required String createdBy,
    required String symptom,
    required DateTime occurredAt,
  }) {
    return {
      'symptom': symptom,
      'createdBy': createdBy,
      'answers': <String, dynamic>{},
      'occurredAt': Timestamp.fromDate(occurredAt),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'schemaVersion': 1,
    };
  }

  /// The fields an edit of an [otherSymptom] log writes. Cleared notes are
  /// deleted, and `createdBy` and `createdAt` are left alone, as the security
  /// rules expect.
  static Map<String, dynamic> otherToFirestoreUpdate({
    required String title,
    required DateTime occurredAt,
    String? notes,
  }) {
    return {
      'title': title,
      'occurredAt': Timestamp.fromDate(occurredAt),
      'notes': notes == null || notes.isEmpty ? FieldValue.delete() : notes,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
