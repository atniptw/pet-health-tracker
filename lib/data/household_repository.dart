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

  /// Every household [uid] is a member of, read from the server, so with no
  /// connection it fails instead of missing households only the server has.
  Future<List<Household>> myHouseholdsFromServer(String uid) async {
    final snapshot = await _households
        .where('memberIds', arrayContains: uid)
        .get(const GetOptions(source: Source.server));
    return snapshot.docs.map(Household.fromFirestore).toList();
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

  /// Changes the household's name. The rules allow this only for admins.
  Future<void> renameHousehold({required String householdId, required String name}) {
    return _households.doc(householdId).update({
      'name': name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Makes [toUid] the household's owner, and an admin if they weren't.
  /// The old owner stays an admin. The rules allow this only for the owner.
  Future<void> transferOwnership({required String householdId, required String toUid}) {
    return _households.doc(householdId).update({
      'ownerId': toUid,
      'adminIds': FieldValue.arrayUnion([toUid]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Makes [uid], a member, an admin. The rules allow this only for the owner.
  Future<void> makeAdmin({required String householdId, required String uid}) {
    return _households.doc(householdId).update({
      'adminIds': FieldValue.arrayUnion([uid]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Takes admin away from [uid], who stays a member. The rules allow this
  /// only for the owner, and never for the owner themselves.
  Future<void> removeAdmin({required String householdId, required String uid}) {
    return _households.doc(householdId).update({
      'adminIds': FieldValue.arrayRemove([uid]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Deletes the household and everything in it: its pets with their logs
  /// and medications, its invites, and its members' names. The rules allow
  /// this only for the owner.
  ///
  /// Unlike other writes this waits for the server: it reads from the server
  /// first, so it fails with no connection instead of missing documents only
  /// the server has. The household goes last, with the names, since the rules
  /// for everything else need it to exist.
  Future<void> deleteHousehold(String householdId) async {
    const server = GetOptions(source: Source.server);
    final household = _households.doc(householdId);
    final pets = (await household.collection('pets').get(server)).docs;
    final refs = <DocumentReference>[];
    for (final pet in pets) {
      for (final collection in ['symptomLogs', 'medications']) {
        refs.addAll(
          (await pet.reference.collection(collection).get(server)).docs.map((d) => d.reference),
        );
      }
    }
    refs.addAll(pets.map((pet) => pet.reference));
    final invites = await _invitesOf(householdId).get(server);
    refs.addAll(invites.docs.map((d) => d.reference));
    final members = (await household.collection('members').get(server)).docs;

    // A batch holds at most 500 writes.
    for (var i = 0; i < refs.length; i += 500) {
      final batch = _firestore.batch();
      for (final ref in refs.skip(i).take(500)) {
        batch.delete(ref);
      }
      await batch.commit();
    }
    final last = _firestore.batch();
    for (final member in members) {
      last.delete(member.reference);
    }
    last.delete(household);
    await last.commit();
  }

  /// Removes [uid] from the household's members and admins and deletes
  /// their member doc, so their logs show "Former member". The rules allow
  /// this for anyone but the owner.
  Future<void> leaveHousehold({required String householdId, required String uid}) {
    return _takeOut(householdId, uid).commit();
  }

  /// Takes [uid] out of the household's members and admins, deletes their
  /// name, so their logs show "Former member", and deletes the household's
  /// invites, so they can't rejoin with the active code. The rules allow
  /// admins to remove members who aren't admins, and the owner anyone else.
  ///
  /// Like deleting the household, this waits for the server: it reads the
  /// invites from the server first, so it fails with no connection instead
  /// of missing an invite only the server has.
  Future<void> removeMember({required String householdId, required String uid}) async {
    final invites = await _invitesOf(householdId).get(const GetOptions(source: Source.server));
    final batch = _takeOut(householdId, uid);
    for (final invite in invites.docs) {
      batch.delete(invite.reference);
    }
    await batch.commit();
  }

  /// A batch that takes [uid] out of the household's members and admins and
  /// deletes their member doc, as leaving and removing both do.
  WriteBatch _takeOut(String householdId, String uid) {
    final household = _households.doc(householdId);
    return _firestore.batch()
      ..update(household, {
        'memberIds': FieldValue.arrayRemove([uid]),
        'adminIds': FieldValue.arrayRemove([uid]),
        'updatedAt': FieldValue.serverTimestamp(),
      })
      ..delete(household.collection('members').doc(uid));
  }

  Query<Map<String, dynamic>> _invitesOf(String householdId) {
    return _firestore.collection('invites').where('householdId', isEqualTo: householdId);
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
