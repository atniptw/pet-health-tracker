import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pet_health_tracker/core/firebase_providers.dart';
import 'package:pet_health_tracker/data/household.dart';
import 'package:pet_health_tracker/data/pet.dart';
import 'package:pet_health_tracker/data/pet_repository.dart';
import 'package:pet_health_tracker/data/symptom_catalog.dart';
import 'package:pet_health_tracker/data/symptom_log_repository.dart';
import 'package:pet_health_tracker/features/symptoms/log_sheet.dart';
import 'package:pet_health_tracker/features/symptoms/symptom_details_screen.dart';
import 'package:pet_health_tracker/features/symptoms/symptom_providers.dart';

import '../../helpers.dart';

class MockSymptomLogRepository extends Mock implements SymptomLogRepository {}

void main() {
  const household = Household(id: 'h1', name: 'The Den', memberIds: ['u1'], adminIds: ['u1']);

  const catalog = SymptomCatalog([
    CatalogSymptom(key: 'seizure', label: 'Seizure'),
    CatalogSymptom(key: 'cough', label: 'Cough', retired: true),
    CatalogSymptom(key: 'vomit', label: 'Vomit'),
  ]);

  late FakeFirebaseFirestore firestore;

  setUp(() => firestore = FakeFirebaseFirestore());

  /// Adds pets named [names] and returns the household's pets in list order.
  Future<List<Pet>> addPets(List<String> names) async {
    final repository = PetRepository(firestore);
    for (final name in names) {
      await repository.addPet(householdId: 'h1', name: name, species: Species.dog);
    }
    return repository.watchPets('h1').first;
  }

  Future<void> addLog(Pet pet, String title, {String createdBy = 'u1', int daysAgo = 1}) {
    return firestore.collection('households/h1/pets/${pet.id}/symptomLogs').add({
      'symptom': 'other',
      'title': title,
      'createdBy': createdBy,
      'occurredAt': Timestamp.fromDate(DateTime.now().subtract(Duration(days: daysAgo))),
      'schemaVersion': 1,
    });
  }

  Future<List<Map<String, dynamic>>> logsOf(Pet pet) async {
    final snapshot = await firestore.collection('households/h1/pets/${pet.id}/symptomLogs').get();
    return [for (final doc in snapshot.docs) doc.data()];
  }

  /// Pumps a screen with a button that opens the sheet, and opens it.
  Future<void> openSheet(
    WidgetTester tester,
    List<Pet> pets, {
    SymptomLogRepository? repository,
  }) async {
    await tester.pumpScoped(
      Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showLogSheet(context, household: household, uid: 'u1', pets: pets),
            child: const Text('Open'),
          ),
        ),
      ),
      overrides: [
        petRepositoryProvider.overrideWithValue(PetRepository(firestore)),
        symptomLogRepositoryProvider.overrideWithValue(
          repository ?? SymptomLogRepository(firestore),
        ),
        symptomCatalogProvider.overrideWith((ref) => Stream.value(catalog)),
      ],
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  Future<void> logSomethingElse(WidgetTester tester, String title) async {
    await tester.tap(find.text('Something else…'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), title);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
  }

  testWidgets('with one pet, hides "Who" and logs something else for it', (tester) async {
    final pets = await addPets(['Boogie']);
    await openSheet(tester, pets);

    expect(find.text('Who'), findsNothing);
    await logSomethingElse(tester, '  Ate a sock ');

    final logs = await logsOf(pets.single);
    expect(logs.single['title'], 'Ate a sock');
    expect(logs.single['symptom'], 'other');
    expect(logs.single['createdBy'], 'u1');
    expect(
      (logs.single['occurredAt'] as Timestamp).toDate().difference(DateTime.now()).inMinutes,
      0,
    );
    expect(find.text('What happened'), findsNothing);
    expect(find.text('Ate a sock logged for Boogie'), findsOneWidget);
  });

  testWidgets('asks for a title, and Back returns to the list', (tester) async {
    final pets = await addPets(['Boogie']);
    await openSheet(tester, pets);
    await tester.tap(find.text('Something else…'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Enter a title'), findsOneWidget);
    expect(await logsOf(pets.single), isEmpty);

    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Something else…'), findsOneWidget);
  });

  testWidgets('submitting the keyboard saves the title', (tester) async {
    final pets = await addPets(['Boogie']);
    await openSheet(tester, pets);
    await tester.tap(find.text('Something else…'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Limping');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect((await logsOf(pets.single)).single['title'], 'Limping');
  });

  testWidgets('picks the first pet when the user has logged nothing', (tester) async {
    final pets = await addPets(['Boogie', 'Pootz']);
    await addLog(pets[1], 'Sneezing', createdBy: 'someone else');
    await openSheet(tester, pets);

    expect(find.text('Who'), findsOneWidget);
    await logSomethingElse(tester, 'Limping');

    expect(await logsOf(pets[0]), hasLength(1));
  });

  testWidgets("picks the pet of the user's last log, and another when tapped", (tester) async {
    final pets = await addPets(['Boogie', 'Kiwi', 'Pootz']);
    await addLog(pets[2], 'Sneezing');
    await openSheet(tester, pets);

    expect(find.byIcon(Icons.check), findsOneWidget);
    await logSomethingElse(tester, 'Limping');
    expect(await logsOf(pets[2]), hasLength(2));

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kiwi'));
    await tester.pumpAndSettle();
    await logSomethingElse(tester, 'Limping');
    expect(await logsOf(pets[1]), hasLength(1));
  });

  testWidgets('with more than 4 pets, puts the last-logged pet first in a row', (tester) async {
    final pets = await addPets(['Boogie', 'Juno', 'Kiwi', 'Mabel', 'Olive']);
    await addLog(pets[4], 'Sneezing');
    await openSheet(tester, pets);

    expect(find.text('Who · last logged for Olive'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Olive').last).dx,
      lessThan(tester.getTopLeft(find.text('Boogie')).dx),
    );

    await tester.tap(find.text('Juno'));
    await tester.pumpAndSettle();
    await logSomethingElse(tester, 'Limping');
    expect(await logsOf(pets[1]), hasLength(1));
  });

  testWidgets('with more than 4 pets and nothing logged, labels the row "Who"', (tester) async {
    final pets = await addPets(['Boogie', 'Juno', 'Kiwi', 'Mabel', 'Olive']);
    await openSheet(tester, pets);

    expect(find.text('Who'), findsOneWidget);
  });

  testWidgets("offers the pet's earlier titles and logs one on tap", (tester) async {
    final pets = await addPets(['Boogie', 'Pootz']);
    await addLog(pets[0], 'Ate a sock', daysAgo: 2);
    await addLog(pets[0], 'Limping, back left leg');
    await addLog(pets[1], 'Sneezing', createdBy: 'someone else');
    await openSheet(tester, pets);

    expect(find.text('Logged before for Boogie'), findsOneWidget);
    expect(find.text('Sneezing'), findsNothing);
    await tester.tap(find.text('Pootz'));
    await tester.pumpAndSettle();
    expect(find.text('Logged before for Pootz'), findsOneWidget);
    await tester.tap(find.text('Sneezing'));
    await tester.pumpAndSettle();

    expect(await logsOf(pets[1]), hasLength(2));
    expect(find.text('Sneezing logged for Pootz'), findsOneWidget);
  });

  testWidgets('Undo deletes the log just saved', (tester) async {
    final pets = await addPets(['Boogie']);
    await addLog(pets[0], 'Ate a sock');
    await openSheet(tester, pets);
    await tester.tap(find.text('Ate a sock'));
    await tester.pumpAndSettle();
    expect(await logsOf(pets[0]), hasLength(2));

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    expect(await logsOf(pets[0]), hasLength(1));
  });

  testWidgets('says so when the log fails to save', (tester) async {
    final pets = await addPets(['Boogie']);
    final repository = MockSymptomLogRepository();
    when(
      () => repository.watchLogs(
        householdId: any(named: 'householdId'),
        petId: any(named: 'petId'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((_) => Stream.value(const []));
    when(() => repository.newLogId(householdId: 'h1', petId: pets[0].id)).thenReturn('log1');
    when(
      () => repository.addOtherLog(
        householdId: any(named: 'householdId'),
        petId: any(named: 'petId'),
        logId: any(named: 'logId'),
        createdBy: any(named: 'createdBy'),
        title: any(named: 'title'),
        occurredAt: any(named: 'occurredAt'),
      ),
    ).thenAnswer((_) => Future.error('offline'));
    await openSheet(tester, pets, repository: repository);
    await logSomethingElse(tester, 'Limping');

    expect(find.text("Couldn't save the log: offline"), findsOneWidget);
  });

  testWidgets("lists the catalog's current symptoms, then something else", (tester) async {
    final pets = await addPets(['Boogie']);
    await openSheet(tester, pets);

    expect(find.text('Cough'), findsNothing);
    final tops = [
      for (final label in ['Seizure', 'Vomit', 'Something else…'])
        tester.getTopLeft(find.text(label)).dy,
    ];
    expect(tops, orderedEquals([...tops]..sort()));
  });

  testWidgets('picking a symptom saves it for the pet and opens its questions', (tester) async {
    final pets = await addPets(['Boogie', 'Pootz']);
    await openSheet(tester, pets);
    await tester.tap(find.text('Pootz'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vomit'));
    await tester.pumpAndSettle();

    final logs = await logsOf(pets[1]);
    expect((logs.single['symptom'], logs.single['createdBy']), ('vomit', 'u1'));
    expect(logs.single['answers'], isEmpty);
    expect(find.byType(LogSheet), findsNothing);
    final details = tester.widget<SymptomDetailsScreen>(find.byType(SymptomDetailsScreen));
    expect((details.householdId, details.petId, details.petName), ('h1', pets[1].id, 'Pootz'));
    expect((details.log.symptom, details.log.createdBy), ('vomit', 'u1'));
    final snapshot = await firestore
        .collection('households/h1/pets/${pets[1].id}/symptomLogs')
        .get();
    expect(details.log.id, snapshot.docs.single.id);
  });

  testWidgets('says so when a catalog log fails to save', (tester) async {
    final pets = await addPets(['Boogie']);
    final repository = MockSymptomLogRepository();
    when(
      () => repository.watchLogs(
        householdId: any(named: 'householdId'),
        petId: any(named: 'petId'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((_) => Stream.value(const []));
    when(() => repository.newLogId(householdId: 'h1', petId: pets[0].id)).thenReturn('log1');
    when(
      () => repository.addCatalogLog(
        householdId: any(named: 'householdId'),
        petId: any(named: 'petId'),
        logId: any(named: 'logId'),
        createdBy: any(named: 'createdBy'),
        symptom: any(named: 'symptom'),
        occurredAt: any(named: 'occurredAt'),
      ),
    ).thenAnswer((_) => Future.error('offline'));
    await openSheet(tester, pets, repository: repository);
    await tester.tap(find.text('Seizure'));
    await tester.pumpAndSettle();

    expect(find.text("Couldn't save the log: offline"), findsOneWidget);
  });
}
