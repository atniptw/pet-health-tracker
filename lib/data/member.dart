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

  /// A new member doc. [inviteId] is the invite used to join; the creator has none.
  static Map<String, dynamic> toFirestore({required String name, String? inviteId}) {
    return {
      'name': name,
      'inviteId': ?inviteId,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'schemaVersion': 1,
    };
  }

  /// The fields a former member rewrites when joining again, merged into their
  /// kept doc so its `createdAt` stays.
  static Map<String, dynamic> rejoinFields({required String name, required String inviteId}) {
    return {
      'name': name,
      'inviteId': inviteId,
      'updatedAt': FieldValue.serverTimestamp(),
      'schemaVersion': 1,
    };
  }
}
