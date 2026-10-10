import 'package:cloud_firestore/cloud_firestore.dart';

/// A member's name in one household. The doc ID is the member's uid, and the
/// doc is kept after they leave so their logs keep their name.
class Member {
  const Member({required this.uid, required this.name});

  final String uid;
  final String name;

  factory Member.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    return Member(uid: doc.id, name: doc.data()!['name'] as String);
  }

  static Map<String, dynamic> toFirestore({required String name}) {
    return {
      'name': name,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'schemaVersion': 1,
    };
  }
}
