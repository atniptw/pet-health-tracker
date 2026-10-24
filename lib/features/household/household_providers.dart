import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/firebase_providers.dart';
import '../../data/household.dart';
import '../../data/last_household_store.dart';

final lastHouseholdStoreProvider = Provider<LastHouseholdStore>((ref) {
  return LastHouseholdStore(SharedPreferencesAsync());
});

/// Keyed by uid so switching users (sign out, sign in as someone else) gets a
/// fresh provider instance with no carried-over state, rather than reusing
/// one provider's stream across identities.
final myHouseholdsProvider = StreamProvider.autoDispose.family<List<Household>, String>((ref, uid) {
  return ref.watch(householdRepositoryProvider).watchMyHouseholds(uid);
});

/// [household] as [myHouseholdsProvider] has it for [uid], so changes like a
/// rename or someone joining show; [household] itself until that loads, or
/// once [uid] is no longer in it.
Household watchHousehold(WidgetRef ref, Household household, String uid) {
  final households = ref.watch(myHouseholdsProvider(uid)).value ?? const <Household>[];
  return households.where((h) => h.id == household.id).firstOrNull ?? household;
}

/// The household the user last opened on this device, by ID. Switching
/// updates it right away and saves it in the background.
class LastHousehold extends AsyncNotifier<String?> {
  LastHousehold(this.uid);

  final String uid;

  @override
  Future<String?> build() => ref.watch(lastHouseholdStoreProvider).read(uid);

  Future<void> select(String householdId) {
    state = AsyncData(householdId);
    return ref.read(lastHouseholdStoreProvider).write(uid, householdId);
  }
}

final lastHouseholdProvider = AsyncNotifierProvider.autoDispose
    .family<LastHousehold, String?, String>(LastHousehold.new);

/// Whether the user still needs to give their name in the household.
final nameMissingProvider = StreamProvider.autoDispose
    .family<bool, ({String householdId, String uid})>((ref, key) {
      return ref
          .watch(householdRepositoryProvider)
          .watchNameMissing(householdId: key.householdId, uid: key.uid);
    });

/// Members' names in the household by uid, former members included.
final memberNamesProvider = StreamProvider.autoDispose.family<Map<String, String>, String>((
  ref,
  householdId,
) {
  return ref.watch(householdRepositoryProvider).watchMemberNames(householdId);
});
