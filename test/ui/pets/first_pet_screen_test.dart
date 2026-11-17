import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_health_tracker/data/repositories.dart';
import 'package:pet_health_tracker/domain/pet.dart';
import 'package:pet_health_tracker/ui/app_scope.dart';
import 'package:pet_health_tracker/ui/history/pet_history_screen.dart';
import 'package:pet_health_tracker/ui/pets/archived_pets_screen.dart';
import 'package:pet_health_tracker/ui/pets/first_pet_screen.dart';

import '../../support/failing_pets.dart';
import '../../support/robot.dart';
import '../../support/screen_checks.dart';
import '../../support/test_app.dart';

Finder get saveButton => find.widgetWithText(FilledButton, 'Save');

Finder get seeArchived => find.widgetWithText(TextButton, 'See archived pets');

Finder get nameField => find.widgetWithText(TextField, 'Name');

/// Pumps the first pet screen in [app].
Future<void> pumpScreen(WidgetTester tester, TestApp app) =>
    tester.pumpWidget(app.wrap(FirstPetScreen(clock: app.clock)));

/// A [PetRepository] whose archived pets come from [archived]; anything
/// else is unused by the screen.
class ArchivedPetsFrom implements PetRepository {
  ArchivedPetsFrom(this.archived);

  final Stream<List<Pet>> archived;

  @override
  Stream<List<Pet>> watchArchived() => archived;

  @override
  Never noSuchMethod(Invocation invocation) => throw UnimplementedError();
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
          child: MaterialApp(home: FirstPetScreen(clock: app.clock)),
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

  testWidgets('001-EC-08: no archived pets → no "See archived pets"', (tester) async {
    await pumpScreen(tester, app);
    await tester.pumpAndSettle();

    expect(seeArchived, findsNothing);
  });

  testWidgets('001-EC-08 001-FR-015: archived pets → "See archived pets" opens Archived pets, '
      'and each pet\'s history', (tester) async {
    final mia = (await tester.runAsync(() => app.pets.add(name: 'Mia', species: Species.cat)))!;
    await tester.runAsync(() => app.pets.setArchived(mia.id, true));
    await pumpScreen(tester, app);
    await tester.pumpAndSettle();
    expect(find.text('Add your first pet'), findsOneWidget);

    await tester.tap(seeArchived);
    await tester.pumpAndSettle();
    expect(find.byType(ArchivedPetsScreen), findsOneWidget);
    await tester.tap(find.widgetWithText(ListTile, 'Mia'));
    await tester.pumpAndSettle();

    expect(tester.widget<PetHistoryScreen>(find.byType(PetHistoryScreen)).pet.name, 'Mia');
  });

  testWidgets('a failed read of the archived pets is reported without a pet\'s name and leaves '
      'out "See archived pets" (D-030)', (tester) async {
    final archived = StreamController<List<Pet>>();
    addTearDown(archived.close);
    await tester.pumpWidget(
      AppScope(
        pets: ArchivedPetsFrom(archived.stream),
        eventTypes: app.eventTypes,
        events: app.events,
        child: MaterialApp(home: FirstPetScreen(clock: app.clock)),
      ),
    );

    archived.addError(Exception('SELECT FROM pets failed for Mia'), StackTrace.current);
    await tester.pumpAndSettle();

    final error = tester.takeException();
    expect(error, isNotNull);
    expect(error.toString(), isNot(contains('Mia')));
    expect(seeArchived, findsNothing);
    expect(find.text('Add your first pet'), findsOneWidget);
  });

  testWidgets('the first pet screen with "See archived pets" is accessible', (tester) async {
    final mia = (await tester.runAsync(() => app.pets.add(name: 'Mia', species: Species.cat)))!;
    await tester.runAsync(() => app.pets.setArchived(mia.id, true));
    await pumpScreen(tester, app);
    await tester.pumpAndSettle();

    await expectAccessible(tester);
  });
}
