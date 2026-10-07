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
import 'package:pet_health_tracker/features/household/home_screen.dart';
import 'package:pet_health_tracker/features/pets/all_pets_screen.dart';
import 'package:pet_health_tracker/features/pets/pet_form_screen.dart';
import 'package:pet_health_tracker/features/settings/settings_screen.dart';
import 'package:pet_health_tracker/features/symptoms/pet_logs_screen.dart';
import 'package:pet_health_tracker/features/symptoms/symptom_providers.dart';

import '../helpers.dart';

class MockPetRepository extends Mock implements PetRepository {}

class MockSymptomLogRepository extends Mock implements SymptomLogRepository {}

void main() {
  const household = Household(
    id: 'h1',
    name: 'The Den',
    memberIds: ['admin', 'member'],
    adminIds: ['admin'],
  );

  const catalog = SymptomCatalog([
    CatalogSymptom(
      key: 'vomit',
      label: 'Vomit',
      questions: [
        CatalogQuestion(
          key: 'content',
          label: 'What came up',
          type: QuestionType.singleChoice,
          options: [CatalogOption(key: 'foamOrBile', label: 'Foam or bile')],
        ),
        CatalogQuestion(key: 'blood', label: 'Blood', type: QuestionType.yesNo),
      ],
    ),
  ]);

  late FakeFirebaseFirestore firestore;
  late PetRepository pets;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    pets = PetRepository(firestore);
  });

  Future<void> pumpHome(WidgetTester tester, {String uid = 'admin'}) {
    return tester.pumpScoped(
      HomeScreen(household: household, uid: uid),
      overrides: [
        petRepositoryProvider.overrideWithValue(pets),
        symptomLogRepositoryProvider.overrideWithValue(SymptomLogRepository(firestore)),
        symptomCatalogProvider.overrideWith((ref) => Stream.value(catalog)),
      ],
    );
  }

  Future<String> addPet(String name, {Species species = Species.dog}) async {
    await pets.addPet(householdId: 'h1', name: name, species: species);
    final snapshot = await firestore.collection('households/h1/pets').get();
    return snapshot.docs.firstWhere((doc) => doc['name'] == name).id;
  }

  Future<void> addLog(
    String petId,
    DateTime occurredAt, {
    String symptom = 'other',
    String? title,
    Map<String, Object> answers = const {},
  }) {
    return firestore.collection('households/h1/pets/$petId/symptomLogs').add({
      'symptom': symptom,
      'title': ?title,
      'answers': answers,
      'createdBy': 'admin',
      'occurredAt': Timestamp.fromDate(occurredAt),
      'schemaVersion': 1,
    });
  }

  testWidgets('shows the household name', (tester) async {
    await pumpHome(tester);

    expect(find.text('The Den'), findsOneWidget);
  });

  testWidgets('opens settings from the app bar', (tester) async {
    await pumpHome(tester);
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();

    expect(find.byType(SettingsScreen), findsOneWidget);
  });

  testWidgets('an admin with no pets is offered to add the first one', (tester) async {
    await pumpHome(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add your first pet'));
    await tester.pumpAndSettle();

    final form = tester.widget<PetFormScreen>(find.byType(PetFormScreen));
    expect((form.householdId, form.pet), ('h1', null));
  });

  testWidgets('a member with no pets is told to ask an admin', (tester) async {
    await pumpHome(tester, uid: 'member');
    await tester.pumpAndSettle();

    expect(find.text('No pets yet. Ask a household admin to add one.'), findsOneWidget);
    expect(find.text('Add your first pet'), findsNothing);
  });

  testWidgets("lists the household's pets with species and breed", (tester) async {
    await pets.addPet(householdId: 'h1', name: 'Boogie', species: Species.dog, breed: 'Beagle');
    await pets.addPet(householdId: 'h1', name: 'Pootz', species: Species.cat);

    await pumpHome(tester);
    await tester.pumpAndSettle();

    expect(find.text('Boogie'), findsOneWidget);
    expect(find.text('Dog · Beagle'), findsOneWidget);
    expect(find.text('Pootz'), findsOneWidget);
    expect(find.text('Cat'), findsOneWidget);
    expect(find.text('All pets'), findsNothing);
  });

  testWidgets('more than 4 pets show as a row of names with an "All pets" link', (tester) async {
    for (final name in ['Boogie', 'Juno', 'Kiwi', 'Mabel', 'Olive']) {
      await addPet(name);
    }

    await pumpHome(tester);
    await tester.pumpAndSettle();

    expect(find.text('Olive'), findsOneWidget);
    expect(find.text('Dog'), findsNothing);
    await tester.tap(find.text('All pets'));
    await tester.pumpAndSettle();

    final screen = tester.widget<AllPetsScreen>(find.byType(AllPetsScreen));
    expect((screen.household.id, screen.uid), ('h1', 'admin'));
  });

  testWidgets('tapping a pet in the row opens its logs', (tester) async {
    for (final name in ['Boogie', 'Juno', 'Kiwi', 'Mabel', 'Olive']) {
      await addPet(name);
    }

    await pumpHome(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Juno'));
    await tester.pumpAndSettle();

    expect(tester.widget<PetLogsScreen>(find.byType(PetLogsScreen)).pet.name, 'Juno');
  });

  testWidgets('says so when nothing has been logged', (tester) async {
    await addPet('Boogie');

    await pumpHome(tester);
    await tester.pumpAndSettle();

    expect(find.text('RECENT'), findsOneWidget);
    expect(find.text('Nothing logged yet'), findsOneWidget);
  });

  testWidgets("lists the household's 5 newest logs across pets", (tester) async {
    final boogie = await addPet('Boogie');
    final pootz = await addPet('Pootz', species: Species.cat);
    final today = DateUtils.dateOnly(DateTime.now());
    await addLog(boogie, today.subtract(const Duration(days: 30)), title: 'Too old');
    for (var day = 1; day <= 4; day++) {
      await addLog(pootz, today.subtract(Duration(days: day)), title: 'Sneezing $day');
    }
    await addLog(
      boogie,
      today.add(const Duration(hours: 6, minutes: 40)),
      symptom: 'vomit',
      answers: {'content': 'foamOrBile', 'blood': true},
    );

    await pumpHome(tester);
    await tester.pumpAndSettle();

    expect(find.text('Vomit'), findsOneWidget);
    expect(find.text('Boogie · Foam or bile · Blood'), findsOneWidget);
    expect(find.text('6:40 AM'), findsOneWidget);
    expect(find.text('Sneezing 1'), findsOneWidget);
    expect(find.text('Yesterday'), findsOneWidget);
    expect(find.text('Sneezing 4'), findsOneWidget);
    expect(find.text('Pootz'), findsNWidgets(5));
    expect(find.text('Too old'), findsNothing);
    expect(find.text('Nothing logged yet'), findsNothing);
  });

  testWidgets('shows the error when recent logs fail to load', (tester) async {
    final repository = MockSymptomLogRepository();
    when(
      () => repository.watchLogs(
        householdId: any(named: 'householdId'),
        petId: any(named: 'petId'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((_) => Stream.error('offline'));
    await addPet('Boogie');

    await tester.pumpScoped(
      const HomeScreen(household: household, uid: 'admin'),
      overrides: [
        petRepositoryProvider.overrideWithValue(pets),
        symptomLogRepositoryProvider.overrideWithValue(repository),
        symptomCatalogProvider.overrideWith((ref) => Stream.value(catalog)),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.text('offline'), findsOneWidget);
  });

  testWidgets('shows a spinner while pets load', (tester) async {
    final repository = MockPetRepository();
    when(() => repository.watchPets('h1')).thenAnswer((_) => const Stream.empty());

    await tester.pumpScoped(
      const HomeScreen(household: household, uid: 'admin'),
      overrides: [petRepositoryProvider.overrideWithValue(repository)],
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('shows the error when pets fail to load and retries on tap', (tester) async {
    final repository = MockPetRepository();
    when(() => repository.watchPets('h1')).thenAnswer((_) => Stream.error('offline'));

    await tester.pumpScoped(
      const HomeScreen(household: household, uid: 'admin'),
      overrides: [petRepositoryProvider.overrideWithValue(repository)],
    );
    await tester.pumpAndSettle();
    expect(find.text('offline'), findsOneWidget);

    when(() => repository.watchPets('h1')).thenAnswer((_) => Stream.value(const <Pet>[]));
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.text('Add your first pet'), findsOneWidget);
  });

  testWidgets('tapping a pet opens its logs, not the edit form', (tester) async {
    await pets.addPet(householdId: 'h1', name: 'Boogie', species: Species.dog);

    await pumpHome(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Boogie'));
    await tester.pumpAndSettle();

    expect(find.byType(PetFormScreen), findsNothing);
    final screen = tester.widget<PetLogsScreen>(find.byType(PetLogsScreen));
    expect(
      (screen.householdId, screen.pet.name, screen.uid, screen.isAdmin),
      ('h1', 'Boogie', 'admin', true),
    );
  });

  testWidgets("a member's pet logs know they aren't an admin", (tester) async {
    await pets.addPet(householdId: 'h1', name: 'Boogie', species: Species.dog);

    await pumpHome(tester, uid: 'member');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Boogie'));
    await tester.pumpAndSettle();

    expect(tester.widget<PetLogsScreen>(find.byType(PetLogsScreen)).isAdmin, isFalse);
  });
}
