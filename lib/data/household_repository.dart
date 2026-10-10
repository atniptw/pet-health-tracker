import 'package:cloud_firestore/cloud_firestore.dart';

import 'household.dart';
import 'invite.dart';
import 'invite_code.dart';
import 'member.dart';

/// Thrown when no unexpired invite matches the code.
class InviteNotFoundException implements Exception {
  const InviteNotFoundException();

  @override
  String toString() =>
      'No household found for that code. Check the spelling, or ask for a new code.';
}

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

  /// Creates the household and the owner's member doc in one batch, and
  /// returns the household's ID.
  Future<String> createHousehold({
    required String name,
    required String ownerUid,
    required String ownerName,
  }) async {
    final household = _households.doc();
    await (_firestore.batch()
          ..set(household, Household.toFirestore(name: name, ownerUid: ownerUid))
          ..set(household.collection('members').doc(ownerUid), Member.toFirestore(name: ownerName)))
        .commit();
    return household.id;
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

  /// Joins the household whose invite matches [code], as a member named
  /// [name], and returns the household's ID. Someone already in it just gets
  /// its ID.
  Future<String> joinHousehold({
    required String code,
    required String uid,
    required String name,
    DateTime Function()? now,
  }) async {
    final inviteId = inviteIdFor(code);
    final inviteDoc = await _firestore.collection('invites').doc(inviteId).get();
    if (!inviteDoc.exists) throw const InviteNotFoundException();
    final invite = Invite.fromFirestore(inviteDoc);
    if (!invite.isActiveAt((now ?? DateTime.now)())) throw const InviteNotFoundException();

    final household = _households.doc(invite.householdId);
    if (await _isMember(household, uid)) return household.id;

    final member = household.collection('members').doc(uid);
    WriteBatch joinWith(void Function(WriteBatch batch) writeMember) {
      final batch = _firestore.batch()
        ..update(household, {
          'memberIds': FieldValue.arrayUnion([uid]),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      writeMember(batch);
      return batch;
    }

    try {
      await joinWith(
        (batch) => batch.set(member, Member.toFirestore(name: name, inviteId: inviteId)),
      ).commit();
    } on FirebaseException catch (e) {
      if (e.code != 'permission-denied') rethrow;
      // A former member's doc is kept, and can't be read before joining.
      // Creating it again is refused, so merge into it instead.
      try {
        await joinWith(
          (batch) => batch.set(
            member,
            Member.rejoinFields(name: name, inviteId: inviteId),
            SetOptions(merge: true),
          ),
        ).commit();
      } on FirebaseException catch (e) {
        // Refused again: the invite expired or was replaced meanwhile.
        if (e.code == 'permission-denied') throw const InviteNotFoundException();
        rethrow;
      }
    }
    return household.id;
  }

  /// Whether [uid] is already in [household]. Only members can read it.
  Future<bool> _isMember(DocumentReference<Map<String, dynamic>> household, String uid) async {
    try {
      final snapshot = await household.get();
      return snapshot.exists && Household.fromFirestore(snapshot).memberIds.contains(uid);
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') return false;
      rethrow;
    }
  }
}
