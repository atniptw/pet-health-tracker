import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/firebase_providers.dart';
import '../../data/symptom_log.dart';

/// A pet's logs, most recent first.
final symptomLogsProvider = StreamProvider.autoDispose
    .family<List<SymptomLog>, ({String householdId, String petId})>((ref, pet) {
      return ref
          .watch(symptomLogRepositoryProvider)
          .watchLogs(householdId: pet.householdId, petId: pet.petId);
    });
