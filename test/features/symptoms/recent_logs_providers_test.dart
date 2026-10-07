import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_health_tracker/core/firebase_providers.dart';
import 'package:pet_health_tracker/features/pets/pet_providers.dart';
import 'package:pet_health_tracker/features/symptoms/symptom_providers.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late ProviderContainer container;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    container = ProviderContainer.test(
      retry: (retryCount, error) => null,
      overrides: [firestoreProvider.overrideWithValue(firestore)],
    );
  });

  Future<void> addPet(String id, String name) =>
      firestore.doc('households/h1/pets/$id').set({'name': name, 'species': 'dog'});

  var logCount = 0;
  Future<void> addLog(
    String petId,
    DateTime occurredAt, {
    String symptom = 'other',
    String? title,
    String createdBy = 'u1',
  }) {
    return firestore
        .collection('households/h1/pets/$petId/symptomLogs')
        .doc('log${logCount++}')
        .set({
          'symptom': symptom,
          'title': ?title,
          'createdBy': createdBy,
          'occurredAt': Timestamp.fromDate(occurredAt),
          'schemaVersion': 1,
        });
  }

  /// The provider's value once its streams have emitted.
  Future<AsyncValue<T>> settled<T>(ProviderListenable<AsyncValue<T>> provider) async {
    final subscription = container.listen(provider, (previous, next) {});
    for (var turn = 0; turn < 50 && subscription.read().isLoading; turn++) {
      await Future<void>.delayed(Duration.zero);
    }
    return subscription.read();
  }

  group('recentLogsProvider', () {
    test("merges every pet's logs, newest first, with each log's pet", () async {
      await addPet('p1', 'Boogie');
      await addPet('p2', 'Pootz');
      await addLog('p1', DateTime(2026, 10, 4), title: 'Ate a sock');
      await addLog('p2', DateTime(2026, 10, 6), symptom: 'vomit');
      await addLog('p1', DateTime(2026, 10, 5), symptom: 'seizure');
      await addLog('p2', DateTime(2026, 10, 1), title: 'Limping');

      final recent = await settled(recentLogsProvider((householdId: 'h1', limit: 3)));

      expect(recent.value!.map((entry) => (entry.pet.name, entry.log.symptom)), [
        ('Pootz', 'vomit'),
        ('Boogie', 'seizure'),
        ('Boogie', 'other'),
      ]);
    });

    test('is empty for a household with no pets', () async {
      final recent = await settled(recentLogsProvider((householdId: 'h1', limit: 3)));

      expect(recent.value, isEmpty);
    });

    test('updates when a log is added', () async {
      await addPet('p1', 'Boogie');
      await settled(recentLogsProvider((householdId: 'h1', limit: 3)));

      await addLog('p1', DateTime(2026, 10, 6), symptom: 'vomit');
      final recent = await settled(recentLogsProvider((householdId: 'h1', limit: 3)));

      expect(recent.value!.single.log.symptom, 'vomit');
    });

    test('reports an error reading the pets', () async {
      container = ProviderContainer.test(
        retry: (retryCount, error) => null,
        overrides: [
          firestoreProvider.overrideWithValue(firestore),
          petsProvider.overrideWith((ref, householdId) => Stream.error('permission-denied')),
        ],
      );

      final recent = await settled(recentLogsProvider((householdId: 'h1', limit: 3)));

      expect(recent.error, 'permission-denied');
    });
  });

  group('recentOtherTitlesProvider', () {
    test("lists the pet's recent other titles once each, newest first", () async {
      await addPet('p1', 'Boogie');
      await addPet('p2', 'Pootz');
      await addLog('p1', DateTime(2026, 10, 6), title: 'Ate a sock');
      await addLog('p1', DateTime(2026, 10, 5), title: 'Limping, back left leg');
      await addLog('p1', DateTime(2026, 10, 4), title: 'ate a sock');
      await addLog('p1', DateTime(2026, 10, 3), symptom: 'vomit');
      await addLog('p1', DateTime(2026, 10, 2), title: 'Sneezing');
      await addLog('p1', DateTime(2026, 10, 1), title: 'Scratching');
      await addLog('p2', DateTime(2026, 10, 7), title: 'Hiding');

      final titles = await settled(
        recentOtherTitlesProvider((householdId: 'h1', petId: 'p1', limit: 3)),
      );

      expect(titles.value, ['Ate a sock', 'Limping, back left leg', 'Sneezing']);
    });
  });

  group('lastLoggedPetIdProvider', () {
    test("is the pet of the user's newest log, ignoring other members'", () async {
      await addPet('p1', 'Boogie');
      await addPet('p2', 'Pootz');
      await addLog('p1', DateTime(2026, 10, 5), symptom: 'vomit');
      await addLog('p2', DateTime(2026, 10, 4), symptom: 'vomit');
      await addLog('p2', DateTime(2026, 10, 6), symptom: 'vomit', createdBy: 'u2');

      final petId = await settled(lastLoggedPetIdProvider((householdId: 'h1', uid: 'u1')));

      expect(petId.value, 'p1');
    });

    test('is null when the user has logged nothing', () async {
      await addPet('p1', 'Boogie');
      await addLog('p1', DateTime(2026, 10, 6), symptom: 'vomit', createdBy: 'u2');

      final petId = await settled(lastLoggedPetIdProvider((householdId: 'h1', uid: 'u1')));

      expect(petId.hasValue, isTrue);
      expect(petId.value, isNull);
    });
  });
}
