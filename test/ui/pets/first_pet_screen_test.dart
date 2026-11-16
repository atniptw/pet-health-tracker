import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_health_tracker/domain/pet.dart';
import 'package:pet_health_tracker/ui/app_scope.dart';
import 'package:pet_health_tracker/ui/pets/first_pet_screen.dart';

import '../../support/failing_pets.dart';
import '../../support/robot.dart';
import '../../support/screen_checks.dart';
import '../../support/test_app.dart';

Finder get saveButton => find.widgetWithText(FilledButton, 'Save');

Finder get nameField => find.widgetWithText(TextField, 'Name');

/// Pumps the first pet screen in [app]. It's built through a constructor
/// tear-off rather than as a constant: the full coverage run misses the
/// constructor line of a widget only ever built as a constant.
Future<void> pumpScreen(WidgetTester tester, TestApp app) {
  const screen = FirstPetScreen.new;
  return tester.pumpWidget(app.wrap(screen()));
}

bool isEnabled(WidgetTester tester, Finder button) =>
    tester.widget<FilledButton>(button).onPressed != null;

void main() {
  late TestApp app;

  setUp(() async => app = await openTestApp());

  Future<List<Pet>> activePets(WidgetTester tester) async =>
      (await tester.runAsync(() => app.pets.watchActive().first))!;

  testWidgets('001-US3-S1: no pets → asked to add the first pet, with name, species and Save', (
    tester,
  ) async {
    await pumpScreen(tester, app);

    expect(find.text('Add your first pet'), findsOneWidget);
    expect(nameField, findsOneWidget);
    expect(
      tester
          .widgetList<ChoiceChip>(find.byType(ChoiceChip))
          .map((chip) => (chip.label as Text).data),
      ['Dog', 'Cat', 'Other'],
    );
    expect(isEnabled(tester, saveButton), isFalse);
    await expectAccessible(tester);

    await tester.enterText(nameField, 'Rex');
    await tester.pump();
    expect(isEnabled(tester, saveButton), isTrue);
  });

  testWidgets(
    '001-US3-S1: saving the first pet adds it, and the screen keeps its fields with Save disabled',
    (tester) async {
      await pumpScreen(tester, app);

      await Robot(tester).addPet('Rex', Species.cat);

      final pets = await activePets(tester);
      expect(pets.map((pet) => (pet.name, pet.species)), [('Rex', Species.cat)]);
      expect(find.byType(FirstPetScreen), findsOneWidget);
      expect(tester.widget<TextField>(nameField).controller!.text, 'Rex');
      expect(tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Cat')).selected, isTrue);
      expect(isEnabled(tester, saveButton), isFalse);
    },
  );

  testWidgets(
    '001-US3-S1: when saving the first pet fails, Save is enabled again and the error reported leaves out the name',
    (tester) async {
      await tester.pumpWidget(
        AppScope(
          pets: FailingPets(),
          eventTypes: app.eventTypes,
          events: app.events,
          child: const MaterialApp(home: FirstPetScreen()),
        ),
      );
      await tester.enterText(nameField, 'Rex');
      await tester.pump();

      final errors = <Object>[];
      await runZonedGuarded(() => tester.tap(saveButton), (error, _) => errors.add(error));
      await tester.pump();

      expect(errors, hasLength(1));
      expect(errors.single.toString(), isNot(contains('Rex')));
      expect(isEnabled(tester, saveButton), isTrue);
    },
  );
}
