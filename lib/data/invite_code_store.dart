import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'invite.dart';
import 'invite_code.dart';

/// Keeps invite codes on the phone of the admin who made them, in the
/// platform's secure storage. Firestore only ever has their hash.
class InviteCodeStore {
  InviteCodeStore(this._storage);

  final FlutterSecureStorage _storage;

  String _key(String uid, String householdId) => 'inviteCode.$uid.$householdId';

  Future<String?> read({required String uid, required String householdId}) =>
      _storage.read(key: _key(uid, householdId));

  Future<void> write({required String uid, required String householdId, required String code}) =>
      _storage.write(key: _key(uid, householdId), value: code);

  Future<void> delete({required String uid, required String householdId}) =>
      _storage.delete(key: _key(uid, householdId));
}

/// [saved] if it is the code for [invite], the household's active invite;
/// otherwise null, because the saved code expired or was replaced.
String? savedCodeFor(Invite? invite, String? saved) {
  if (invite == null || saved == null) return null;
  return inviteIdFor(saved) == invite.id ? saved : null;
}
