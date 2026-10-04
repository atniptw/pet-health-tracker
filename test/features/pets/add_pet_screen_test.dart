import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pet_health_tracker/core/firebase_providers.dart';
import 'package:pet_health_tracker/data/pet.dart';
import 'package:pet_health_tracker/data/pet_repository.dart';
import 'package:pet_health_tracker/features/pets/add_pet_screen.dart';

import '../../helpers.dart';

class MockPetRepository extends Mock implements PetRepository {}

void main() {
  late MockPetRepository repository;

  setUpAll(() => registerFallbackValue(Species.dog));

  void stubAdd(Future<void> Function() answer) {
    when(
      () => repository.addPet(
        householdId: any(named: 'householdId'),
        name: any(named: 'name'),
        species: any(named: 'species'),
        breed: any(named: 'breed'),
        birthDate: any(named: 'birthDate'),
        sex: any(named: 'sex'),
      ),
    ).thenAnswer((_) => answer());
  }

  void verifyNoAdd() {
    verifyNever(
      () => repository.addPet(
        householdId: any(named: 'householdId'),
        name: any(named: 'name'),
        species: any(named: 'species'),
        breed: any(named: 'breed'),
        birthDate: any(named: 'birthDate'),
        sex: any(named: 'sex'),
      ),
    );
  }

  setUp(() {
    repository = MockPetRepository();
    stubAdd(() async {});
  });

  /// Pushes the screen from a host page, so popping it can be seen.
  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpScoped(
      Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute<void>(builder: (_) => const AddPetScreen(householdId: 'h1'))),
            child: const Text('open'),
          ),
        ),
      ),
      overrides: [petRepositoryProvider.overrideWithValue(repository)],
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Finder nameField() => find.widgetWithText(TextField, 'Name');
  Finder breedField() => find.widgetWithText(TextField, 'Breed (optional)');

  Future<void> tapAdd(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(FilledButton, 'Add pet'));
    await tester.pumpAndSettle();
  }

  testWidgets('asks for a name and species before saving', (tester) async {
    await pumpScreen(tester);
    await tapAdd(tester);

    expect(find.text('Enter a name'), findsOneWidget);
    expect(find.text('Choose a species'), findsOneWidget);
    verifyNoAdd();

    await tester.enterText(nameField(), 'Boogie');
    await tester.pump();
    expect(find.text('Enter a name'), findsNothing);

    await tester.tap(find.text('Dog'));
    await tester.pump();
    expect(find.text('Choose a species'), findsNothing);
  });

  testWidgets('treats a blank name as missing', (tester) async {
    await pumpScreen(tester);
    await tester.enterText(nameField(), '   ');
    await tester.tap(find.text('Cat'));
    await tapAdd(tester);

    expect(find.text('Enter a name'), findsOneWidget);
    verifyNoAdd();
  });

  testWidgets('deselecting the species makes it missing again', (tester) async {
    await pumpScreen(tester);
    await tester.enterText(nameField(), 'Boogie');
    await tester.tap(find.text('Dog'));
    await tester.pump();
    await tester.tap(find.text('Dog'));
    await tapAdd(tester);

    expect(find.text('Choose a species'), findsOneWidget);
    verifyNoAdd();
  });

  testWidgets('adds a pet with only a name and species, then closes', (tester) async {
    await pumpScreen(tester);
    await tester.enterText(nameField(), '  Boogie  ');
    await tester.tap(find.text('Dog'));
    await tapAdd(tester);

    verify(
      () => repository.addPet(
        householdId: 'h1',
        name: 'Boogie',
        species: Species.dog,
        breed: '',
        birthDate: null,
        sex: null,
      ),
    ).called(1);
    expect(find.byType(AddPetScreen), findsNothing);
  });

  testWidgets('adds a pet with every optional field', (tester) async {
    await pumpScreen(tester);
    await tester.enterText(nameField(), 'Pootz');
    await tester.tap(find.text('Cat'));
    await tester.enterText(breedField(), ' Tabby ');
    await tester.tap(find.text('Female'));
    await tester.pump();
    await tester.tap(find.text('Male'));
    await tester.tap(find.text('Birth date (optional)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tapAdd(tester);

    final now = DateTime.now();
    verify(
      () => repository.addPet(
        householdId: 'h1',
        name: 'Pootz',
        species: Species.cat,
        breed: 'Tabby',
        birthDate: DateTime(now.year, now.month, now.day),
        sex: Sex.male,
      ),
    ).called(1);
  });

  testWidgets('a birth date can be cleared, and a cancelled pick changes nothing', (tester) async {
    await pumpScreen(tester);
    expect(find.text('Not set'), findsOneWidget);

    await tester.tap(find.text('Birth date (optional)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('Not set'), findsNothing);

    await tester.tap(find.text('Birth date (optional)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Not set'), findsNothing);

    await tester.tap(find.byTooltip('Clear birth date'));
    await tester.pump();
    expect(find.text('Not set'), findsOneWidget);
  });

  testWidgets('shows a spinner while saving', (tester) async {
    final completer = Completer<void>();
    stubAdd(() => completer.future);

    await pumpScreen(tester);
    await tester.enterText(nameField(), 'Boogie');
    await tester.tap(find.text('Dog'));
    await tester.tap(find.widgetWithText(FilledButton, 'Add pet'));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Add pet'), findsNothing);

    completer.complete();
    await tester.pumpAndSettle();
    expect(find.byType(AddPetScreen), findsNothing);
  });

  testWidgets('shows the error and stays open when saving fails', (tester) async {
    stubAdd(() async => throw Exception('permission denied'));

    await pumpScreen(tester);
    await tester.enterText(nameField(), 'Boogie');
    await tester.tap(find.text('Dog'));
    await tapAdd(tester);

    expect(find.textContaining('permission denied'), findsOneWidget);
    expect(find.byType(AddPetScreen), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Add pet'), findsOneWidget);
  });
}
