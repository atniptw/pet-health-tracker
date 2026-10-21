import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/firebase_providers.dart';
import '../../data/household_repository.dart';
import '../../data/invite_code_store.dart';
import '../../data/last_household_store.dart';
import '../household/household_providers.dart';
import '../household/invite_providers.dart';
import 'auth_repository.dart';

/// Thrown when the user owns a household no choice was made for, such as one
/// made on another phone after they started deleting their account.
class OwnedHouseholdsChangedException implements Exception {
  const OwnedHouseholdsChangedException();

  @override
  String toString() => 'Your households changed. Check them and try again.';
}

final accountDeletionProvider = Provider<AccountDeletion>((ref) {
  return AccountDeletion(
    auth: ref.watch(authRepositoryProvider),
    households: ref.watch(householdRepositoryProvider),
    lastHouseholds: ref.watch(lastHouseholdStoreProvider),
    inviteCodes: ref.watch(inviteCodeStoreProvider),
  );
});

/// Deletes the signed-in user's account and their data.
class AccountDeletion {
  AccountDeletion({
    required this._auth,
    required this._households,
    required this._lastHouseholds,
    required this._inviteCodes,
  });

  final AuthRepository _auth;
  final HouseholdRepository _households;
  final LastHouseholdStore _lastHouseholds;
  final InviteCodeStore _inviteCodes;

  /// Deletes [uid]'s account. [newOwners] has, for each household they own,
  /// the member to hand it to, or null to delete it. They leave every other
  /// household, so their name is deleted and their logs show "Former member".
  ///
  /// Signs in again first, so cancelling changes nothing. Waits for the
  /// server throughout; the account itself goes last, so after a failure
  /// trying again picks up where it stopped.
  Future<void> delete({required String uid, required Map<String, String?> newOwners}) async {
    final appleAuthorizationCode = await _auth.reauthenticate();
    final households = await _households.myHouseholdsFromServer(uid);
    if (households.any((h) => h.ownerId == uid && !newOwners.containsKey(h.id))) {
      throw const OwnedHouseholdsChangedException();
    }
    for (final household in households) {
      if (household.ownerId == uid && newOwners[household.id] == null) {
        await _households.deleteHousehold(household.id);
        continue;
      }
      if (household.ownerId == uid) {
        await _households.transferOwnership(
          householdId: household.id,
          toUid: newOwners[household.id]!,
        );
      }
      await _households.leaveHousehold(householdId: household.id, uid: uid);
    }
    await _lastHouseholds.delete(uid);
    await _inviteCodes.deleteAll(uid);
    await _auth.deleteUser(appleAuthorizationCode: appleAuthorizationCode);
  }
}
