import 'package:cloud_firestore/cloud_firestore.dart';

class Household {
  const Household({
    required this.id,
    required this.name,
    required this.memberIds,
    required this.adminIds,
    this.ownerId,
  });

  final String id;
  final String name;
  final List<String> memberIds;
  final List<String> adminIds;

  /// The member who can delete the household or transfer it. Null for
  /// households made before owners existed.
  final String? ownerId;

  factory Household.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return Household(
      id: doc.id,
      name: data['name'] as String,
      memberIds: List<String>.from(data['memberIds'] as List),
      adminIds: List<String>.from(data['adminIds'] as List),
      ownerId: data['ownerId'] as String?,
    );
  }

  static Map<String, dynamic> toFirestore({required String name, required String ownerUid}) {
    return {
      'name': name,
      'memberIds': [ownerUid],
      'adminIds': [ownerUid],
      'ownerId': ownerUid,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'schemaVersion': 1,
    };
  }
}
