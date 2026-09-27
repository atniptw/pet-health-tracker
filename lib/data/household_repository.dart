import 'package:cloud_firestore/cloud_firestore.dart';

import 'household.dart';

class HouseholdRepository {
  HouseholdRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _households =>
      _firestore.collection('households');

  /// This slice only builds "create a household," not "join one," so a user
  /// can only ever be a member of the single household they created.
  Stream<Household?> watchMyHousehold(String uid) {
    return _households
        .where('memberIds', arrayContains: uid)
        .limit(1)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) return null;
      return Household.fromFirestore(snapshot.docs.first);
    });
  }

  Future<void> createHousehold({required String name, required String ownerUid}) {
    return _households.add(Household.toFirestore(name: name, ownerUid: ownerUid));
  }
}
