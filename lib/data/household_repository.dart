import 'package:cloud_firestore/cloud_firestore.dart';

import 'household.dart';
import 'member.dart';

class HouseholdRepository {
  HouseholdRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _households => _firestore.collection('households');

  /// Every household [uid] is a member of, sorted by name.
  Stream<List<Household>> watchMyHouseholds(String uid) {
    return _households.where('memberIds', arrayContains: uid).snapshots().map((snapshot) {
      return snapshot.docs.map(Household.fromFirestore).toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
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

  /// Every member's name in the household by uid, former members included.
  Stream<Map<String, String>> watchMemberNames(String householdId) {
    return _households.doc(householdId).collection('members').snapshots().map((snapshot) {
      return {
        for (final member in snapshot.docs.map(Member.fromFirestore)) member.uid: member.name,
      };
    });
  }
}
