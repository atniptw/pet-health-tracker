import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_health_tracker/data/repositories.dart';
import 'package:pet_health_tracker/domain/pet.dart';
import 'package:pet_health_tracker/ui/app_scope.dart';
import 'package:pet_health_tracker/ui/pets/pet_form_screen.dart';

import '../../support/failing_pets.dart';
import '../../support/robot.dart';
import '../../support/screen_checks.dart';
import '../../support/test_app.dart';

/// Pumps a screen with an "Open" button that pushes the pet form for [pet],
/// or for a new pet, and taps it.
Future<void> openForm(WidgetTester tester, TestApp app, {Pet? pet}) async {
  await tester.pumpWidget(
    app.wrap(
      Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () =>
                Navigator.of(context)
                    .push(MaterialPageRoute<void>(builder: (_) => PetFormScreen(pet: pet))),
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

Finder get saveButton => find.widgetWithText(FilledButton, 'Save');

Finder get nameField => find.widgetWithText(TextField, 'Name');

bool isEnabled(WidgetTester tester, Finder button) =>
    tester.widget<FilledButton>(button).onPressed != null;

bool isPicked(WidgetTester tester, Species species) =>
    tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, species.label)).selected;

void main() {
  late TestApp app;

  setUp(() async => app = await openTestApp());

  Future<List<Pet>> activePets(WidgetTester tester) async =>
      (await tester.runAsync(() => app.pets.watchActive().first))!;

  testWidgets('001-FR-001: adding a pet with a name and species saves it and closes the form', (
    tester,
  ) async {
    await openForm(tester, app);
    expect(find.text('Add pet'), findsOneWidget);
    await expectAccessible(tester);

    await Robot(tester).addPet('Rex', Species.cat);

    final pets = await activePets(tester);
    expect(pets.map((pet) => (pet.name, pet.species)), [('Rex', Species.cat)]);
    expect(find.byType(PetFormScreen), findsNothing);
    expect(find.text('Open'), findsOneWidget);
  });

  testWidgets('001-FR-001: species choices are Dog, Cat and Other, with Dog picked at first', (
    tester,
  ) async {
    await openForm(tester, app);

    final labels = tester
        .widgetList<ChoiceChip>(find.byType(ChoiceChip))
        .map((chip) => (chip.label as Text).data);
    expect(labels, ['Dog', 'Cat', 'Other']);
    expect(isPicked(tester, Species.dog), isTrue);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Other'));
    await tester.pump();
    expect(isPicked(tester, Species.other), isTrue);
    expect(isPicked(tester, Species.dog), isFalse);
  });

  testWidgets('001-FR-001: Save is enabled once a name is entered', (tester) async {
    await openForm(tester, app);
    expect(isEnabled(tester, saveButton), isFalse);

    await tester.enterText(nameField, '   ');
    await tester.pump();
    expect(isEnabled(tester, saveButton), isFalse);

    await tester.enterText(nameField, 'Rex');
    await tester.pump();
    expect(isEnabled(tester, saveButton), isTrue);
  });

  testWidgets('001-FR-001: the name is saved trimmed', (tester) async {
    await openForm(tester, app);

    await Robot(tester).addPet('  Rex  ', Species.dog);

    expect((await activePets(tester)).single.name, 'Rex');
  });

  testWidgets('001-FR-001: the name field takes at most 40 characters', (tester) async {
    await openForm(tester, app);

    await Robot(tester).addPet('${'a' * 39}🐶extra', Species.dog);

    expect((await activePets(tester)).single.name, '${'a' * 39}🐶');
  });

  testWidgets('001-FR-001: Save is disabled once tapped, so the pet is added once', (tester) async {
    await openForm(tester, app);
    await tester.enterText(nameField, 'Rex');
    await tester.pump();

    await tester.tap(saveButton);
    await tester.pump();

    expect(isEnabled(tester, saveButton), isFalse);
    await tester.pumpAndSettle();
    expect(await activePets(tester), hasLength(1));
  });

  testWidgets('001-US3-S2: editing a pet shows its name and species', (tester) async {
    final rex = (await tester.runAsync(() => app.pets.add(name: 'Rex', species: Species.cat)))!;

    await openForm(tester, app, pet: rex);

    expect(find.text('Edit pet'), findsOneWidget);
    expect(tester.widget<TextField>(nameField).controller!.text, 'Rex');
    expect(isPicked(tester, Species.cat), isTrue);
    expect(isEnabled(tester, saveButton), isTrue);
    await expectAccessible(tester);
  });

  testWidgets('001-US3-S2: changing a pet\'s name and species keeps its id and its events', (
    tester,
  ) async {
    final (rex, event) = (await tester.runAsync(() async {
      final rex = await app.pets.add(name: 'Rex', species: Species.cat);
      final event = await app.events.log(
        petId: rex.id,
        type: ExistingType('vomiting'),
        occurredAt: DateTime(2026, 11, 14, 9),
      );
      return (rex, event);
    }))!;
    await openForm(tester, app, pet: rex);

    await Robot(tester).addPet('Rexy', Species.dog);

    final pets = await activePets(tester);
    expect(pets.map((pet) => (pet.id, pet.name, pet.species)), [(rex.id, 'Rexy', Species.dog)]);
    final events = (await tester.runAsync(() => app.events.watchForPet(rex.id).first))!;
    expect(events.map((e) => e.id), [event.id]);
    expect(find.byType(PetFormScreen), findsNothing);
  });

  testWidgets(
    '001-FR-001: when saving fails, the form stays open, Save is enabled again and the error reported leaves out the name',
    (tester) async {
      await tester.pumpWidget(
        AppScope(
          pets: FailingPets(),
          eventTypes: app.eventTypes,
          events: app.events,
          child: const MaterialApp(home: PetFormScreen()),
        ),
      );
      await tester.enterText(nameField, 'Rex');
      await tester.pump();

      final errors = <Object>[];
      await runZonedGuarded(() => tester.tap(saveButton), (error, _) => errors.add(error));
      await tester.pump();

      expect(errors, hasLength(1));
      expect(errors.single.toString(), isNot(contains('Rex')));
      expect(find.byType(PetFormScreen), findsOneWidget);
      expect(isEnabled(tester, saveButton), isTrue);
    },
  );
}
