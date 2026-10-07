import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/firebase_providers.dart';
import '../../data/pet.dart';
import '../../data/symptom_catalog.dart';
import '../../data/symptom_log.dart';
import '../pets/pet_providers.dart';

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

/// A log, with the pet it's for.
typedef PetLog = ({Pet pet, SymptomLog log});

/// How many of each pet's latest logs the recent providers read. Ordering by
/// `occurredAt` alone needs no composite index, so the home screen's queries
/// work in production without deploying one.
const _latestPerPet = 50;

final _latestLogsProvider = StreamProvider.autoDispose
    .family<List<SymptomLog>, ({String householdId, String petId})>((ref, pet) {
      return ref
          .watch(symptomLogRepositoryProvider)
          .watchLogs(householdId: pet.householdId, petId: pet.petId, limit: _latestPerPet);
    });

/// The latest logs of every pet in the household, newest first. Loading until
/// every pet's logs are read.
final _householdLatestLogsProvider = Provider.autoDispose.family<AsyncValue<List<PetLog>>, String>((
  ref,
  householdId,
) {
  final petsState = ref.watch(petsProvider(householdId));
  if (petsState.hasError) return AsyncError(petsState.error!, petsState.stackTrace!);
  final pets = petsState.value;
  if (pets == null) return const AsyncLoading();

  final logs = <PetLog>[];
  for (final pet in pets) {
    final petLogs = ref.watch(_latestLogsProvider((householdId: householdId, petId: pet.id)));
    if (petLogs.hasError) return AsyncError(petLogs.error!, petLogs.stackTrace!);
    final value = petLogs.value;
    if (value == null) return const AsyncLoading();
    logs.addAll([for (final log in value) (pet: pet, log: log)]);
  }
  logs.sort((a, b) => b.log.occurredAt.compareTo(a.log.occurredAt));
  return AsyncData(logs);
});

/// The household's newest logs across all pets, at most [limit].
final recentLogsProvider = Provider.autoDispose
    .family<AsyncValue<List<PetLog>>, ({String householdId, int limit})>((ref, key) {
      return ref
          .watch(_householdLatestLogsProvider(key.householdId))
          .whenData((logs) => logs.take(key.limit).toList());
    });

/// Titles of the pet's recent `other` logs, newest first, each once (ignoring
/// case), at most [limit].
final recentOtherTitlesProvider = Provider.autoDispose
    .family<AsyncValue<List<String>>, ({String householdId, String petId, int limit})>((ref, key) {
      return ref
          .watch(_latestLogsProvider((householdId: key.householdId, petId: key.petId)))
          .whenData((logs) {
            final seen = <String>{};
            return [
              for (final log in logs)
                if (log.title case final title? when seen.add(title.toLowerCase())) title,
            ].take(key.limit).toList();
          });
    });

/// The pet of [uid]'s newest log, or null when they have logged nothing
/// recently.
final lastLoggedPetIdProvider = Provider.autoDispose
    .family<AsyncValue<String?>, ({String householdId, String uid})>((ref, key) {
      return ref.watch(_householdLatestLogsProvider(key.householdId)).whenData((logs) {
        for (final (:pet, :log) in logs) {
          if (log.createdBy == key.uid) return pet.id;
        }
        return null;
      });
    });
