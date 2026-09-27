import 'package:cloud_firestore/cloud_firestore.dart';

class Household {
  const Household({
    required this.id,
    required this.name,
    required this.memberIds,
    required this.adminIds,
  });

  final String id;
  final String name;
  final List<String> memberIds;
  final List<String> adminIds;

  factory Household.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return Household(
      id: doc.id,
      name: data['name'] as String,
      memberIds: List<String>.from(data['memberIds'] as List),
      adminIds: List<String>.from(data['adminIds'] as List),
    );
  }

  static Map<String, dynamic> toFirestore({
    required String name,
    required String ownerUid,
  }) {
    return {
      'name': name,
      'memberIds': [ownerUid],
      'adminIds': [ownerUid],
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'schemaVersion': 1,
    };
  }
}
