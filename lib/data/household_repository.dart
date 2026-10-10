import 'package:cloud_firestore/cloud_firestore.dart';

import 'household.dart';
import 'member.dart';

class HouseholdRepository {
  HouseholdRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _households => _firestore.collection('households');

  /// This slice only builds "create a household," not "join one," so a user
  /// can only ever be a member of the single household they created.
  Stream<Household?> watchMyHousehold(String uid) {
    return _households.where('memberIds', arrayContains: uid).limit(1).snapshots().map((snapshot) {
      if (snapshot.docs.isEmpty) return null;
      return Household.fromFirestore(snapshot.docs.first);
    });
  }

  /// Creates the household and the owner's member doc in one batch.
  Future<void> createHousehold({
    required String name,
    required String ownerUid,
    required String ownerName,
  }) {
    final household = _households.doc();
    return (_firestore.batch()
          ..set(household, Household.toFirestore(name: name, ownerUid: ownerUid))
          ..set(household.collection('members').doc(ownerUid), Member.toFirestore(name: ownerName)))
        .commit();
  }

  /// Emits true when the server confirms [uid] has no member doc (no name) in
  /// the household. Emits false while that is only known from the cache, so
  /// a phone with no signal isn't asked for a name it may already have.
  Stream<bool> watchNameMissing({required String householdId, required String uid}) {
    return _households
        .doc(householdId)
        .collection('members')
        .doc(uid)
        .snapshots(includeMetadataChanges: true)
        .map((snapshot) => !snapshot.exists && !snapshot.metadata.isFromCache)
        .distinct();
  }

  /// Creates [uid]'s member doc in the household with [name].
  Future<void> addMemberName({
    required String householdId,
    required String uid,
    required String name,
  }) {
    return _households
        .doc(householdId)
        .collection('members')
        .doc(uid)
        .set(Member.toFirestore(name: name));
  }
}
