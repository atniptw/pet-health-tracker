import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_health_tracker/app.dart';
import 'package:pet_health_tracker/data/repositories.dart';
import 'package:pet_health_tracker/domain/pet.dart';
import 'package:pet_health_tracker/ui/log/log_screen.dart';
import 'package:pet_health_tracker/ui/pets/first_pet_screen.dart';

import 'support/robot.dart';
import 'support/test_app.dart';

/// A [PetRepository] whose active pets are the lists and errors the test
/// sends; like the local one, a new listener first gets the last list sent.
/// Anything else is unused by the app's screens here.
class ControlledPets implements PetRepository {
  final _changes = StreamController<List<Pet>>.broadcast();
  List<Pet>? _last;

  void send(List<Pet> active) {
    _last = active;
    _changes.add(active);
  }

  void fail(Object error) => _changes.addError(error, StackTrace.current);

  @override
  Stream<List<Pet>> watchActive() async* {
    if (_last case final last?) yield last;
    yield* _changes.stream;
  }

  @override
  Never noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

Pet pet(String id, String name) =>
    Pet(id: id, name: name, species: Species.dog, createdAt: DateTime.utc(2026));

/// A read error naming a pet, as sqflite's `DatabaseException` can.
final readError = Exception('SELECT FROM pets failed for Rex');

void main() {
  late TestApp app;

  setUp(() async => app = await openTestApp());

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      App(pets: app.pets, eventTypes: app.eventTypes, events: app.events, clock: app.clock),
    );
    await tester.pumpAndSettle();
  }

  Future<void> addPet(WidgetTester tester, String name) async {
    await tester.runAsync(() => app.pets.add(name: name, species: Species.dog));
    await tester.pumpAndSettle();
  }

  testWidgets('001-US3-S1: no pets → the app opens on "Add your first pet"', (tester) async {
    await pumpApp(tester);

    expect(find.byType(FirstPetScreen), findsOneWidget);
    expect(find.text('Add your first pet'), findsOneWidget);
    expect(find.byType(LogScreen), findsNothing);
  });

  testWidgets('001-US3-S1: adding the first pet → the log screen, with the pet as its heading', (
    tester,
  ) async {
    await pumpApp(tester);

    await Robot(tester).addPet('Rex', Species.dog);

    expect(find.byType(FirstPetScreen), findsNothing);
    expect(find.byType(LogScreen), findsOneWidget);
    expect(find.text('Rex'), findsOneWidget);
  });

  testWidgets('001-US1-S1: a pet exists → the app opens on the log screen', (tester) async {
    await tester.runAsync(() => app.pets.add(name: 'Rex', species: Species.dog));

    await pumpApp(tester);

    expect(find.byType(LogScreen), findsOneWidget);
    expect(find.byType(FirstPetScreen), findsNothing);
  });

  testWidgets('the log screen keeps the picked pet when another pet is added', (tester) async {
    await tester.runAsync(() => app.pets.add(name: 'Rex', species: Species.dog));
    await tester.runAsync(() => app.pets.add(name: 'Mia', species: Species.cat));
    await pumpApp(tester);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Mia'));
    await tester.pump();

    await addPet(tester, 'Bo');

    expect(find.widgetWithText(ChoiceChip, 'Bo'), findsOneWidget);
    expect(tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Mia')).selected, isTrue);
  });

  testWidgets('given other repositories, the start screen follows their pets', (tester) async {
    final other = await openTestApp();
    await tester.runAsync(() => other.pets.add(name: 'Rex', species: Species.dog));
    await pumpApp(tester);
    expect(find.byType(FirstPetScreen), findsOneWidget);

    await tester.pumpWidget(
      App(pets: other.pets, eventTypes: other.eventTypes, events: other.events, clock: other.clock),
    );
    await tester.pumpAndSettle();

    expect(find.byType(LogScreen), findsOneWidget);
    expect(find.text('Rex'), findsOneWidget);
  });

  group('when reading the active pets fails', () {
    late ControlledPets pets;

    setUp(() => pets = ControlledPets());

    Future<void> pumpControlled(WidgetTester tester) async {
      await tester.pumpWidget(
        App(pets: pets, eventTypes: app.eventTypes, events: app.events, clock: app.clock),
      );
      await tester.pumpAndSettle();
    }

    Future<void> emit(WidgetTester tester, {List<Pet>? list}) async {
      if (list == null) {
        pets.fail(readError);
      } else {
        pets.send(list);
      }
      await tester.pumpAndSettle();
    }

    void expectReportedWithoutName(WidgetTester tester) {
      final error = tester.takeException();
      expect(error, isNotNull);
      expect(error.toString(), isNot(contains('Rex')));
    }

    testWidgets('after a list, the log screen stays with its pick, and the error is reported '
        'without the pet\'s name', (tester) async {
      await pumpControlled(tester);
      await emit(tester, list: [pet('a', 'Mia'), pet('b', 'Rex')]);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Mia'));
      await tester.pump();
      final logState = tester.state(find.byType(LogScreen));

      await emit(tester);

      expectReportedWithoutName(tester);
      expect(find.byType(LogScreen), findsOneWidget);
      expect(tester.state(find.byType(LogScreen)), same(logState));
      await emit(tester, list: [pet('a', 'Mia'), pet('b', 'Rex')]);
      expect(tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Mia')).selected, isTrue);
    });

    testWidgets('before any list, says the pets couldn\'t be loaded (D-017) and reports the '
        'error without the pet\'s name', (tester) async {
      await pumpControlled(tester);

      await emit(tester);

      expectReportedWithoutName(tester);
      expect(find.text(App.loadFailed), findsOneWidget);
      expect(find.byType(FirstPetScreen), findsNothing);
      await emit(tester, list: [pet('b', 'Rex')]);
      expect(find.byType(LogScreen), findsOneWidget);
      expect(find.text(App.loadFailed), findsNothing);
    });
  });
}
