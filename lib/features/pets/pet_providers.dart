import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/firebase_providers.dart';
import '../../data/pet.dart';

/// Keyed by household id.
final petsProvider = StreamProvider.autoDispose.family<List<Pet>, String>((ref, householdId) {
  return ref.watch(petRepositoryProvider).watchPets(householdId);
});
