import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'invite.dart';
import 'invite_code.dart';

/// Keeps invite codes on the phone of the admin who made them, in the
/// platform's secure storage. Firestore only ever has their hash.
class InviteCodeStore {
  InviteCodeStore(this._storage);

  final FlutterSecureStorage _storage;

  /// Runs operations one at a time, so a clean-up can't remove a code saved
  /// while it was checking.
  Future<void> _queue = Future.value();

  Future<T> _serially<T>(Future<T> Function() operation) {
    final result = _queue.then((_) => operation());
    _queue = result.then<void>((_) {}, onError: (_) {});
    return result;
  }

  String _key(String uid, String householdId) => 'inviteCode.$uid.$householdId';

  Future<String?> read({required String uid, required String householdId}) =>
      _serially(() => _storage.read(key: _key(uid, householdId)));

  Future<void> write({required String uid, required String householdId, required String code}) =>
      _serially(() => _storage.write(key: _key(uid, householdId), value: code));

  /// Deletes the saved code only if it is still [code].
  Future<void> deleteIfStill({
    required String uid,
    required String householdId,
    required String code,
  }) {
    return _serially(() async {
      final key = _key(uid, householdId);
      if (await _storage.read(key: key) == code) await _storage.delete(key: key);
    });
  }
}

/// [saved] if it is the code for [invite], the household's active invite;
/// otherwise null, because the saved code expired or was replaced.
String? savedCodeFor(Invite? invite, String? saved) {
  if (invite == null || saved == null) return null;
  return inviteIdFor(saved) == invite.id ? saved : null;
}
