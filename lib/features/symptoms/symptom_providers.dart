import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/firebase_providers.dart';
import '../../data/symptom_catalog.dart';
import '../../data/symptom_log.dart';

/// A pet's logs, most recent first.
final symptomLogsProvider = StreamProvider.autoDispose
    .family<List<SymptomLog>, ({String householdId, String petId})>((ref, pet) {
      return ref
          .watch(symptomLogRepositoryProvider)
          .watchLogs(householdId: pet.householdId, petId: pet.petId);
    });

/// The bundled catalog, replaced by the published one once it's read.
final symptomCatalogProvider = StreamProvider<SymptomCatalog>((ref) async* {
  final repository = ref.watch(catalogRepositoryProvider);
  final bundled = await repository.loadBundled();
  yield bundled;
  try {
    await for (final published in repository.watchPublished()) {
      yield published ?? bundled;
    }
  } on Object {
    // Keep the catalog already shown. One that can't be read, for example
    // after signing out, shouldn't stop the app labelling logs.
  }
});
