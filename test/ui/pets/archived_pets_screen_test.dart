import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_health_tracker/data/repositories.dart';
import 'package:pet_health_tracker/domain/pet.dart';
import 'package:pet_health_tracker/ui/app_scope.dart';
import 'package:pet_health_tracker/ui/history/event_tile.dart';
import 'package:pet_health_tracker/ui/history/pet_history_screen.dart';
import 'package:pet_health_tracker/ui/pets/archived_pets_screen.dart';

import '../../support/screen_checks.dart';
import '../../support/test_app.dart';

/// A [PetRepository] whose archived pets are the lists and errors the test
/// sends; anything else is unused by the screen.
class ControlledArchivedPets implements PetRepository {
  final _archived = StreamController<List<Pet>>.broadcast();

  void send(List<Pet> pets) => _archived.add(pets);

  void fail(Object error) => _archived.addError(error, StackTrace.current);

  @override
  Stream<List<Pet>> watchArchived() => _archived.stream;

  @override
  Never noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

/// The names of the listed pets, top to bottom.
List<String?> listedNames(WidgetTester tester) => tester
    .widgetList<ListTile>(find.byType(ListTile))
    .map((tile) => (tile.title as Text?)?.data)
    .toList();

void main() {
  late TestApp app;
  final now = DateTime(2026, 11, 14, 12);

  setUp(() async => app = await openTestApp(now: now));

  Future<Pet> addPet(WidgetTester tester, String name, {bool archived = false}) async {
    final pet = (await tester.runAsync(() => app.pets.add(name: name, species: Species.dog)))!;
    if (archived) await tester.runAsync(() => app.pets.setArchived(pet.id, true));
    return pet;
  }

  Widget screenIn({PetRepository? pets, Key? key}) => AppScope(
    pets: pets ?? app.pets,
    eventTypes: app.eventTypes,
    events: app.events,
    child: MaterialApp(
      home: ArchivedPetsScreen(key: key, clock: () => now),
    ),
  );

  Future<void> openScreen(WidgetTester tester, {PetRepository? pets}) async {
    await tester.pumpWidget(screenIn(pets: pets));
    await tester.pumpAndSettle();
  }

  testWidgets('001-US3-S3 001-FR-015: lists the archived pets by name, leaving out active ones', (
    tester,
  ) async {
    await addPet(tester, 'Rex');
    await addPet(tester, 'Mia', archived: true);
    await addPet(tester, 'Bella', archived: true);

    await openScreen(tester);

    expect(find.widgetWithText(AppBar, 'Archived pets'), findsOneWidget);
    expect(listedNames(tester), ['Bella', 'Mia']);
  });

  testWidgets('001-US3-S3 001-US3-S4: tapping an archived pet opens its history, with its events '
      'and "Restore"', (tester) async {
    final mia = await addPet(tester, 'Mia');
    await tester.runAsync(
      () => app.events.log(
        petId: mia.id,
        type: ExistingType('vomiting'),
        occurredAt: DateTime(2026, 11, 13, 8),
      ),
    );
    await tester.runAsync(() => app.pets.setArchived(mia.id, true));
    await openScreen(tester);

    await tester.tap(find.widgetWithText(ListTile, 'Mia'));
    await tester.pumpAndSettle();

    final history = tester.widget<PetHistoryScreen>(find.byType(PetHistoryScreen));
    expect(history.pet.name, 'Mia');
    expect(find.byType(EventTile), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Restore'), findsOneWidget);
  });

  testWidgets('a pet restored from its history leaves the list', (tester) async {
    await addPet(tester, 'Mia', archived: true);
    await openScreen(tester);
    await tester.tap(find.widgetWithText(ListTile, 'Mia'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, 'Restore'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(listedNames(tester), isEmpty);
    expect(find.text(ArchivedPetsScreen.empty), findsOneWidget);
  });

  testWidgets('no archived pets → "No archived pets"', (tester) async {
    await addPet(tester, 'Rex');

    await openScreen(tester);

    expect(find.text('No archived pets'), findsOneWidget);
    expect(find.byType(ListTile), findsNothing);
  });

  testWidgets('a failed read before any pets says they couldn\'t be loaded (D-030) and reports '
      'the error without a pet\'s name', (tester) async {
    final pets = ControlledArchivedPets();
    await openScreen(tester, pets: pets);

    pets.fail(Exception('SELECT FROM pets failed for Mia'));
    await tester.pumpAndSettle();

    final error = tester.takeException();
    expect(error, isNotNull);
    expect(error.toString(), isNot(contains('Mia')));
    expect(find.text(ArchivedPetsScreen.loadFailed), findsOneWidget);
  });

  testWidgets('a failed read after the pets keeps them shown (D-030)', (tester) async {
    final pets = ControlledArchivedPets();
    await openScreen(tester, pets: pets);
    pets.send([Pet(id: 'p1', name: 'Mia', species: Species.cat, archived: true, createdAt: now)]);
    await tester.pumpAndSettle();

    pets.fail(Exception('SELECT FROM pets failed for Mia'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNotNull);
    expect(listedNames(tester), ['Mia']);
    expect(find.text(ArchivedPetsScreen.loadFailed), findsNothing);
  });

  testWidgets('other repositories → their archived pets', (tester) async {
    await addPet(tester, 'Mia', archived: true);
    final other = ControlledArchivedPets();
    final key = GlobalKey();
    await tester.pumpWidget(screenIn(key: key));
    await tester.pumpAndSettle();
    expect(listedNames(tester), ['Mia']);

    await tester.pumpWidget(screenIn(key: key, pets: other));
    other.send([Pet(id: 'p1', name: 'Bo', species: Species.dog, archived: true, createdAt: now)]);
    await tester.pumpAndSettle();

    expect(listedNames(tester), ['Bo']);
  });

  testWidgets('the archived pets screen is accessible', (tester) async {
    await addPet(tester, 'Mia', archived: true);
    await addPet(tester, 'Bella', archived: true);
    await openScreen(tester);

    await expectAccessible(tester);
  });
}
