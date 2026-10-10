import 'package:cloud_firestore/cloud_firestore.dart';

import 'invite_code.dart';

/// An invite code's record in Firestore. The ID is the code's hash.
class Invite {
  const Invite({required this.id, required this.householdId, required this.createdAt});

  final String id;
  final String householdId;
  final DateTime createdAt;

  DateTime get expiresAt => createdAt.add(inviteLifetime);

  bool isActiveAt(DateTime now) => now.isBefore(expiresAt);

  /// [now] stands in for a just-made invite's server timestamp, which isn't
  /// known until the server has it.
  factory Invite.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc, {DateTime? now}) {
    final data = doc.data()!;
    return Invite(
      id: doc.id,
      householdId: data['householdId'] as String,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? now ?? DateTime.now(),
    );
  }

  static Map<String, dynamic> toFirestore({
    required String householdId,
    required String createdBy,
  }) {
    return {
      'householdId': householdId,
      'createdBy': createdBy,
      'createdAt': FieldValue.serverTimestamp(),
      'schemaVersion': 1,
    };
  }
}
