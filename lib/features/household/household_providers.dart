import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/firebase_providers.dart';
import '../../data/household.dart';

/// Keyed by uid so switching users (sign out, sign in as someone else) gets a
/// fresh provider instance with no carried-over state, rather than reusing
/// one provider's stream across identities.
final myHouseholdProvider = StreamProvider.autoDispose.family<Household?, String>((ref, uid) {
  return ref.watch(householdRepositoryProvider).watchMyHousehold(uid);
});
