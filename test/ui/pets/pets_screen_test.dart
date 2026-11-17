import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_health_tracker/data/repositories.dart';
import 'package:pet_health_tracker/domain/pet.dart';
import 'package:pet_health_tracker/ui/app_scope.dart';
import 'package:pet_health_tracker/ui/history/pet_history_screen.dart';
import 'package:pet_health_tracker/ui/log/log_screen.dart';
import 'package:pet_health_tracker/ui/log/pet_choices.dart';
import 'package:pet_health_tracker/ui/pets/archived_pets_screen.dart';
import 'package:pet_health_tracker/ui/pets/pet_form_screen.dart';
import 'package:pet_health_tracker/ui/pets/pets_screen.dart';

import '../../support/robot.dart';
import '../../support/screen_checks.dart';
import '../../support/test_app.dart';

/// A [PetRepository] whose active pets are the lists and errors the test
/// sends; anything else is unused by the screen.
class ControlledPets implements PetRepository {
  final _active = StreamController<List<Pet>>.broadcast();

  void send(List<Pet> pets) => _active.add(pets);

  void fail(Object error) => _active.addError(error, StackTrace.current);

  @override
  Stream<List<Pet>> watchActive() => _active.stream;

  @override
  Never noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

Finder get addPetButton => find.widgetWithText(TextButton, 'Add pet');

/// The names of the listed pets, top to bottom.
List<String?> listedNames(WidgetTester tester) => tester
    .widgetList<ListTile>(find.byType(ListTile))
    .map((tile) => (tile.title as Text?)?.data)
    .toList();

void main() {
  late TestApp app;
  final now = DateTime(2026, 11, 14, 12);

  setUp(() async => app = await openTestApp(now: now));

  Future<Pet> addPet(WidgetTester tester, String name) async =>
      (await tester.runAsync(() => app.pets.add(name: name, species: Species.dog)))!;

  Widget screenIn({PetRepository? pets, Key? key}) => AppScope(
    pets: pets ?? app.pets,
    eventTypes: app.eventTypes,
    events: app.events,
    child: MaterialApp(
      home: PetsScreen(key: key, clock: () => now),
    ),
  );

  Future<void> openScreen(WidgetTester tester, {PetRepository? pets}) async {
    await tester.pumpWidget(screenIn(pets: pets));
    await tester.pumpAndSettle();
  }

  testWidgets('001-US1-S2: a second pet added through "Pets" → the log screen shows the pet '
      'choices, with the pet last logged for picked', (tester) async {
    await addPet(tester, 'Rex');
    await tester.pumpWidget(app.wrap(LogScreen(clock: () => now)));
    await tester.pumpAndSettle();
    final robot = Robot(tester);
    await robot.logEvent('Vomiting');
    expect(find.byType(PetChoices), findsNothing);

    await tester.tap(find.byTooltip('Menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pets'));
    await tester.pumpAndSettle();
    await tester.tap(addPetButton);
    await tester.pumpAndSettle();
    await robot.addPet('Mia', Species.cat);
    expect(listedNames(tester), ['Mia', 'Rex']);
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.byType(PetChoices), findsOneWidget);
    expect(tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Rex')).selected, isTrue);
    expect(tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Mia')).selected, isFalse);
  });

  testWidgets('lists the active pets by name, leaving out archived ones', (tester) async {
    await addPet(tester, 'Rex');
    await addPet(tester, 'Mia');
    final old = await addPet(tester, 'Bella');
    await tester.runAsync(() => app.pets.setArchived(old.id, true));

    await openScreen(tester);

    expect(find.text('Pets'), findsOneWidget);
    expect(listedNames(tester), ['Mia', 'Rex']);
  });

  testWidgets('tapping a pet opens its history', (tester) async {
    await addPet(tester, 'Rex');
    await addPet(tester, 'Mia');
    await openScreen(tester);

    await tester.tap(find.widgetWithText(ListTile, 'Rex'));
    await tester.pumpAndSettle();

    final history = tester.widget<PetHistoryScreen>(find.byType(PetHistoryScreen));
    expect(history.pet.name, 'Rex');
  });

  testWidgets('"Add pet" opens the pet form, and the added pet is listed', (tester) async {
    await addPet(tester, 'Rex');
    await openScreen(tester);

    await tester.tap(addPetButton);
    await tester.pumpAndSettle();
    expect(find.byType(PetFormScreen), findsOneWidget);
    await Robot(tester).addPet('Mia', Species.cat);

    expect(find.byType(PetFormScreen), findsNothing);
    expect(listedNames(tester), ['Mia', 'Rex']);
  });

  testWidgets('001-US3-S3: "Archived pets" opens the archived pets', (tester) async {
    await addPet(tester, 'Rex');
    final mia = await addPet(tester, 'Mia');
    await tester.runAsync(() => app.pets.setArchived(mia.id, true));
    await openScreen(tester);

    await tester.tap(find.widgetWithText(TextButton, 'Archived pets'));
    await tester.pumpAndSettle();

    expect(find.byType(ArchivedPetsScreen), findsOneWidget);
    expect(listedNames(tester), ['Mia']);
  });

  testWidgets('a failed read before any pets says they couldn\'t be loaded (D-028) and reports '
      'the error without a pet\'s name', (tester) async {
    final pets = ControlledPets();
    await openScreen(tester, pets: pets);

    pets.fail(Exception('SELECT FROM pets failed for Rex'));
    await tester.pumpAndSettle();

    final error = tester.takeException();
    expect(error, isNotNull);
    expect(error.toString(), isNot(contains('Rex')));
    expect(find.text(PetsScreen.loadFailed), findsOneWidget);
    expect(addPetButton, findsOneWidget);
  });

  testWidgets('a failed read after the pets keeps them shown (D-028)', (tester) async {
    final pets = ControlledPets();
    await openScreen(tester, pets: pets);
    final rex = Pet(id: 'p1', name: 'Rex', species: Species.dog, createdAt: now);
    pets.send([rex]);
    await tester.pumpAndSettle();

    pets.fail(Exception('SELECT FROM pets failed for Rex'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNotNull);
    expect(listedNames(tester), ['Rex']);
    expect(find.text(PetsScreen.loadFailed), findsNothing);
  });

  testWidgets('other repositories → their pets', (tester) async {
    await addPet(tester, 'Rex');
    final other = ControlledPets();
    final key = GlobalKey();
    await tester.pumpWidget(screenIn(key: key));
    await tester.pumpAndSettle();
    expect(listedNames(tester), ['Rex']);

    await tester.pumpWidget(screenIn(key: key, pets: other));
    other.send([Pet(id: 'p1', name: 'Mia', species: Species.cat, createdAt: now)]);
    await tester.pumpAndSettle();

    expect(listedNames(tester), ['Mia']);
  });

  testWidgets('the pets screen is accessible', (tester) async {
    await addPet(tester, 'Rex');
    await addPet(tester, 'Mia');
    await openScreen(tester);

    await expectAccessible(tester);
  });
}
