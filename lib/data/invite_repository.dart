import 'package:cloud_firestore/cloud_firestore.dart';

import 'invite.dart';
import 'invite_code.dart';

/// Thrown when another household has an unexpired invite with the same code.
class InviteCodeTakenException implements Exception {
  const InviteCodeTakenException();

  @override
  String toString() => 'That code is taken. Try another.';
}

class InviteRepository {
  InviteRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _invites => _firestore.collection('invites');

  Query<Map<String, dynamic>> _invitesOf(String householdId) =>
      _invites.where('householdId', isEqualTo: householdId);

  /// The household's newest unexpired invite, or null. Only admins can read it.
  Stream<Invite?> watchActiveInvite(String householdId, {DateTime Function()? now}) {
    return _invitesOf(householdId).snapshots().map((snapshot) {
      final at = (now ?? DateTime.now)();
      final active =
          snapshot.docs
              .map((doc) => Invite.fromFirestore(doc, now: at))
              .where((invite) => invite.isActiveAt(at))
              .toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return active.firstOrNull;
    });
  }

  /// Makes [code] the household's invite, replacing any it had, so older codes
  /// stop working.
  Future<void> createInvite({
    required String householdId,
    required String createdBy,
    required String code,
  }) async {
    final id = inviteIdFor(code);
    final existing = await _invitesOf(householdId).get();
    final batch = _firestore.batch();
    for (final doc in existing.docs) {
      if (doc.id != id) batch.delete(doc.reference);
    }
    batch.set(_invites.doc(id), Invite.toFirestore(householdId: householdId, createdBy: createdBy));
    try {
      await batch.commit();
    } on FirebaseException catch (e) {
      // The rules refuse to overwrite another household's unexpired invite.
      if (e.code == 'permission-denied') throw const InviteCodeTakenException();
      rethrow;
    }
  }
}
