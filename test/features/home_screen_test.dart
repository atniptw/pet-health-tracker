import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pet_health_tracker/core/firebase_providers.dart';
import 'package:pet_health_tracker/data/household.dart';
import 'package:pet_health_tracker/data/pet.dart';
import 'package:pet_health_tracker/data/pet_repository.dart';
import 'package:pet_health_tracker/data/symptom_log_repository.dart';
import 'package:pet_health_tracker/features/household/home_screen.dart';
import 'package:pet_health_tracker/features/pets/pet_form_screen.dart';
import 'package:pet_health_tracker/features/settings/settings_screen.dart';
import 'package:pet_health_tracker/features/symptoms/pet_logs_screen.dart';

import '../helpers.dart';

class MockPetRepository extends Mock implements PetRepository {}

void main() {
  const household = Household(
    id: 'h1',
    name: 'The Den',
    memberIds: ['admin', 'member'],
    adminIds: ['admin'],
  );

  late PetRepository pets;

  setUp(() => pets = PetRepository(FakeFirebaseFirestore()));

  Future<void> pumpHome(WidgetTester tester) {
    return tester.pumpScoped(
      const HomeScreen(household: household, uid: 'admin'),
      overrides: [
        petRepositoryProvider.overrideWithValue(pets),
        symptomLogRepositoryProvider.overrideWithValue(
          SymptomLogRepository(FakeFirebaseFirestore()),
        ),
      ],
    );
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

  testWidgets('says so when the household has no pets', (tester) async {
    await pumpHome(tester);
    await tester.pumpAndSettle();

    expect(find.text('No pets yet'), findsOneWidget);
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
    expect(find.text('No pets yet'), findsNothing);
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

    expect(find.text('No pets yet'), findsOneWidget);
  });

  testWidgets('has no add-pet button', (tester) async {
    await pumpHome(tester);
    await tester.pumpAndSettle();

    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.text('Add pet'), findsNothing);
  });

  testWidgets('tapping a pet opens its logs, not the edit form', (tester) async {
    await pets.addPet(householdId: 'h1', name: 'Boogie', species: Species.dog);

    await pumpHome(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Boogie'));
    await tester.pumpAndSettle();

    expect(find.byType(PetFormScreen), findsNothing);
    final screen = tester.widget<PetLogsScreen>(find.byType(PetLogsScreen));
    expect((screen.householdId, screen.pet.name, screen.uid), ('h1', 'Boogie', 'admin'));
  });
}
