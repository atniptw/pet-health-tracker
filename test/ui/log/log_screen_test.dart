import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_health_tracker/data/repositories.dart';
import 'package:pet_health_tracker/domain/built_in_event_types.dart';
import 'package:pet_health_tracker/domain/event_type.dart';
import 'package:pet_health_tracker/domain/medical_event.dart';
import 'package:pet_health_tracker/domain/pet.dart';
import 'package:pet_health_tracker/ui/app_scope.dart';
import 'package:pet_health_tracker/ui/history/pet_history_screen.dart';
import 'package:pet_health_tracker/ui/log/log_screen.dart';
import 'package:pet_health_tracker/ui/log/log_sheet.dart';
import 'package:pet_health_tracker/ui/log/pet_choices.dart';
import 'package:pet_health_tracker/ui/log/type_grid.dart';
import 'package:pet_health_tracker/ui/types/my_event_types_screen.dart';

import '../../support/robot.dart';
import '../../support/screen_checks.dart';
import '../../support/test_app.dart';

Finder chip(String name) => find.widgetWithText(ChoiceChip, name);

Finder typeButton(String name) =>
    find.descendant(of: find.byType(TypeGrid), matching: find.widgetWithText(FilledButton, name));

Finder get saveButton => find.widgetWithText(FilledButton, 'Save');

Finder get historyButton => find.widgetWithText(TextButton, 'History');

/// An [EventRepository] whose `lastLoggedPetId` waits for [lastLogged];
/// anything else is unused by the screen.
class SlowLastLogged implements EventRepository {
  final lastLogged = Completer<String?>();

  @override
  Future<String?> lastLoggedPetId() => lastLogged.future;

  @override
  Never noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

/// A [PetRepository] whose active pets are the lists and errors the test
/// sends. Anything else is unused by these tests.
class ControlledPets implements PetRepository {
  final _active = StreamController<List<Pet>>.broadcast();

  void send(List<Pet> active) => _active.add(active);

  void fail(Object error) => _active.addError(error, StackTrace.current);

  @override
  Stream<List<Pet>> watchActive() => _active.stream;

  @override
  Never noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

/// An [EventTypeRepository] whose offered types are the lists and errors the
/// test sends. Anything else is unused by these tests.
class ControlledTypes implements EventTypeRepository {
  final _offered = StreamController<List<EventType>>.broadcast();

  void send(List<EventType> offered) => _offered.add(offered);

  void fail(Object error) => _offered.addError(error, StackTrace.current);

  @override
  Stream<List<EventType>> watchOffered() => _offered.stream;

  @override
  Never noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

Pet pet(String id, String name) =>
    Pet(id: id, name: name, species: Species.dog, createdAt: DateTime.utc(2026));

void main() {
  late TestApp app;
  final now = DateTime(2026, 11, 14, 12);

  setUp(() async => app = await openTestApp(now: now));

  Future<Pet> addPet(WidgetTester tester, String name) async =>
      (await tester.runAsync(() => app.pets.add(name: name, species: Species.dog)))!;

  Future<void> logged(WidgetTester tester, Pet pet) async {
    await tester.runAsync(
      () => app.events.log(petId: pet.id, type: ExistingType('sneezing'), occurredAt: now),
    );
  }

  Future<List<MedicalEvent>> eventsFor(WidgetTester tester, Pet pet) async =>
      (await tester.runAsync(() => app.events.watchForPet(pet.id).first))!;

  Future<void> openLog(WidgetTester tester) async {
    await tester.pumpWidget(app.wrap(LogScreen(clock: () => now)));
    await tester.pumpAndSettle();
  }

  bool isPicked(WidgetTester tester, String name) => tester.widget<ChoiceChip>(chip(name)).selected;

  String? pickedInChoices(WidgetTester tester) =>
      tester.widget<PetChoices>(find.byType(PetChoices)).pickedId;

  testWidgets('001-US1-S1 001-FR-007 001-SC-001: one pet → its name as a heading, no picker, '
      'and Vomiting saved for it now in two taps', (tester) async {
    final rex = await addPet(tester, 'Rex');
    await openLog(tester);

    expect(find.text('Rex'), findsOneWidget);
    expect(find.byType(PetChoices), findsNothing);
    expect(find.byType(ChoiceChip), findsNothing);

    await tester.tap(typeButton('Vomiting'));
    await tester.pumpAndSettle();
    expect(find.byType(PetChoices), findsNothing);
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(find.text('Saved: Vomiting for Rex'), findsOneWidget);
    final events = await eventsFor(tester, rex);
    expect(events.map((event) => (event.typeId, event.occurredAt)), [('vomiting', now.toUtc())]);
  });

  testWidgets('001-US1-S2 001-SC-001: several pets → the pet last logged for is picked, '
      'and Vomiting is saved for it in two taps', (tester) async {
    await addPet(tester, 'Rex');
    final mia = await addPet(tester, 'Mia');
    await logged(tester, mia);
    await openLog(tester);

    expect(isPicked(tester, 'Mia'), isTrue);
    expect(isPicked(tester, 'Rex'), isFalse);
    expect(find.text('Who is this for?'), findsNothing);

    await tester.tap(typeButton('Vomiting'));
    await tester.pumpAndSettle();
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(find.text('Saved: Vomiting for Mia'), findsOneWidget);
    expect((await eventsFor(tester, mia)).map((event) => event.typeId), ['vomiting', 'sneezing']);
  });

  testWidgets('001-US1-S2: another pet can be picked before saving', (tester) async {
    final rex = await addPet(tester, 'Rex');
    final mia = await addPet(tester, 'Mia');
    await logged(tester, mia);
    await openLog(tester);

    await tester.tap(chip('Rex'));
    await tester.pump();
    expect(isPicked(tester, 'Rex'), isTrue);
    await tester.tap(typeButton('Vomiting'));
    await tester.pumpAndSettle();
    expect(find.descendant(of: find.byType(LogSheet), matching: find.text('Rex')), findsOneWidget);
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(find.text('Saved: Vomiting for Rex'), findsOneWidget);
    expect((await eventsFor(tester, rex)).map((event) => event.typeId), ['vomiting']);
  });

  testWidgets('001-US1-S3: several pets, none logged for → no pet picked, '
      'and one is chosen in the sheet before saving', (tester) async {
    await addPet(tester, 'Rex');
    final mia = await addPet(tester, 'Mia');
    await openLog(tester);

    expect(find.text('Who is this for?'), findsOneWidget);
    expect(isPicked(tester, 'Rex'), isFalse);
    expect(isPicked(tester, 'Mia'), isFalse);

    await tester.tap(typeButton('Vomiting'));
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(saveButton).onPressed, isNull);
    await tester.tap(find.descendant(of: find.byType(LogSheet), matching: chip('Mia')));
    await tester.pump();
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(find.text('Saved: Vomiting for Mia'), findsOneWidget);
    expect((await eventsFor(tester, mia)).map((event) => event.typeId), ['vomiting']);
  });

  testWidgets('001-US1-S3: several pets, the last logged for archived → no pet picked', (
    tester,
  ) async {
    await addPet(tester, 'Rex');
    await addPet(tester, 'Mia');
    final bo = await addPet(tester, 'Bo');
    await logged(tester, bo);
    await tester.runAsync(() => app.pets.setArchived(bo.id, true));
    await openLog(tester);

    expect(find.text('Who is this for?'), findsOneWidget);
    expect(chip('Bo'), findsNothing);
    expect(pickedInChoices(tester), isNull);
  });

  testWidgets('001-US1-S3: the picked pet archived while the screen is open → no pet picked', (
    tester,
  ) async {
    await addPet(tester, 'Rex');
    await addPet(tester, 'Mia');
    final bo = await addPet(tester, 'Bo');
    await logged(tester, bo);
    await openLog(tester);
    expect(isPicked(tester, 'Bo'), isTrue);

    await tester.runAsync(() => app.pets.setArchived(bo.id, true));
    await tester.pumpAndSettle();

    expect(chip('Bo'), findsNothing);
    expect(pickedInChoices(tester), isNull);
    await tester.tap(typeButton('Vomiting'));
    await tester.pumpAndSettle();
    expect(tester.widget<LogSheet>(find.byType(LogSheet)).pickedPetId, isNull);
  });

  testWidgets('001-FR-007: a new event\'s pet becomes the picked one', (tester) async {
    await addPet(tester, 'Rex');
    await addPet(tester, 'Mia');
    await openLog(tester);

    await tester.tap(typeButton('Vomiting'));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(LogSheet), matching: chip('Rex')));
    await tester.pump();
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(isPicked(tester, 'Rex'), isTrue);
    expect(find.text('Who is this for?'), findsNothing);
  });

  testWidgets('001-FR-007: closing the sheet without saving keeps the pick and shows no message', (
    tester,
  ) async {
    await addPet(tester, 'Rex');
    await addPet(tester, 'Mia');
    await openLog(tester);

    await tester.tap(typeButton('Vomiting'));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(LogSheet), matching: chip('Rex')));
    await tester.pump();
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(find.byType(LogSheet), findsNothing);
    expect(find.textContaining('Saved'), findsNothing);
    expect(pickedInChoices(tester), isNull);
  });

  testWidgets('001-FR-002: a button for each offered type, built-in first, then custom ones', (
    tester,
  ) async {
    final rex = await addPet(tester, 'Rex');
    await tester.runAsync(
      () => app.events.log(petId: rex.id, type: NewTypeName('Ear shaking'), occurredAt: now),
    );
    await openLog(tester);

    final labels = tester
        .widgetList<FilledButton>(
          find.descendant(of: find.byType(TypeGrid), matching: find.byType(FilledButton)),
        )
        .map((button) => (button.child! as Text).data);
    expect(labels, [...builtInEventTypes.map((type) => type.name), 'Ear shaking']);
  });

  testWidgets('001-FR-002: each type button opens the log sheet for that type', (tester) async {
    await addPet(tester, 'Rex');
    await openLog(tester);

    await tester.tap(typeButton('Seizure'));
    await tester.pumpAndSettle();

    expect(find.byType(LogSheet), findsOneWidget);
    expect(find.descendant(of: find.byType(LogSheet), matching: find.text('Seizure')), findsOne);
    expect(find.text('How long it lasted'), findsOneWidget);
  });

  testWidgets('001-EC-05: the same thing for two pets is logged once for each', (tester) async {
    final rex = await addPet(tester, 'Rex');
    final mia = await addPet(tester, 'Mia');
    await openLog(tester);
    final robot = Robot(tester);

    await robot.logEvent('Vomiting', pet: 'Rex');
    expect(find.text('Saved: Vomiting for Rex'), findsOneWidget);
    await robot.logEvent('Vomiting', pet: 'Mia');
    expect(find.text('Saved: Vomiting for Mia'), findsOneWidget);

    expect((await eventsFor(tester, rex)).map((event) => event.typeId), ['vomiting']);
    expect((await eventsFor(tester, mia)).map((event) => event.typeId), ['vomiting']);
  });

  testWidgets('a new "Saved" message replaces the one before it (D-013)', (tester) async {
    await addPet(tester, 'Rex');
    await addPet(tester, 'Mia');
    await openLog(tester);
    final robot = Robot(tester);

    await robot.logEvent('Vomiting', pet: 'Rex');
    await robot.logEvent('Sneezing', pet: 'Mia');

    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('Saved: Sneezing for Mia'), findsOneWidget);
    expect(find.text('Saved: Vomiting for Rex'), findsNothing);
  });

  /// The log screen with [key] under the repositories of [repos], except
  /// [events] if given, inside a [ScaffoldMessenger] keyed by [messenger].
  Widget screenIn(
    TestApp repos, {
    required GlobalKey key,
    EventRepository? events,
    Key? messenger,
  }) => AppScope(
    pets: repos.pets,
    eventTypes: repos.eventTypes,
    events: events ?? repos.events,
    child: MaterialApp(
      home: ScaffoldMessenger(
        key: messenger,
        child: LogScreen(key: key, clock: () => now),
      ),
    ),
  );

  testWidgets('001-FR-007: the pick is kept when something else the screen depends on changes', (
    tester,
  ) async {
    await addPet(tester, 'Rex');
    await addPet(tester, 'Mia');
    final key = GlobalKey();
    await tester.pumpWidget(screenIn(app, key: key, messenger: const ValueKey(1)));
    await tester.pumpAndSettle();
    await Robot(tester).logEvent('Vomiting', pet: 'Rex');
    await tester.tap(chip('Mia'));
    await tester.pump();

    await tester.pumpWidget(screenIn(app, key: key, messenger: const ValueKey(2)));
    await tester.pumpAndSettle();

    expect(isPicked(tester, 'Mia'), isTrue);
    expect(isPicked(tester, 'Rex'), isFalse);
  });

  testWidgets('other repositories → their pets, types and last logged pet', (tester) async {
    final rex = await addPet(tester, 'Rex');
    await addPet(tester, 'Mia');
    await tester.runAsync(
      () => app.events.log(petId: rex.id, type: NewTypeName('Limping badly'), occurredAt: now),
    );
    final other = (await tester.runAsync(() => openTestApp(now: now)))!;
    await tester.runAsync(() async {
      await other.pets.add(name: 'Bo', species: Species.cat);
      final ivy = await other.pets.add(name: 'Ivy', species: Species.cat);
      await other.events.log(petId: ivy.id, type: NewTypeName('Ear shaking'), occurredAt: now);
    });
    final key = GlobalKey();
    await tester.pumpWidget(screenIn(app, key: key));
    await tester.pumpAndSettle();
    await tester.tap(chip('Rex'));
    await tester.pump();

    await tester.pumpWidget(screenIn(other, key: key));
    await tester.pumpAndSettle();

    expect(chip('Rex'), findsNothing);
    expect(typeButton('Ear shaking'), findsOneWidget);
    expect(typeButton('Limping badly'), findsNothing);
    expect(isPicked(tester, 'Ivy'), isTrue);
    expect(isPicked(tester, 'Bo'), isFalse);
  });

  testWidgets('a last logged pet read from replaced repositories is not picked', (tester) async {
    await addPet(tester, 'Rex');
    final mia = await addPet(tester, 'Mia');
    final slow = SlowLastLogged();
    final key = GlobalKey();
    await tester.pumpWidget(screenIn(app, key: key, events: slow));
    await tester.pumpAndSettle();

    await tester.pumpWidget(screenIn(app, key: key));
    await tester.pumpAndSettle();
    slow.lastLogged.complete(mia.id);
    await tester.pumpAndSettle();

    expect(pickedInChoices(tester), isNull);
  });

  testWidgets('001-US2-S1: one pet → "History" opens its history', (tester) async {
    await addPet(tester, 'Rex');
    await openLog(tester);

    await tester.tap(historyButton);
    await tester.pumpAndSettle();

    expect(tester.widget<PetHistoryScreen>(find.byType(PetHistoryScreen)).pet.name, 'Rex');
  });

  testWidgets('001-US2-S1: several pets → "History" opens the picked pet\'s history', (
    tester,
  ) async {
    await addPet(tester, 'Rex');
    await addPet(tester, 'Mia');
    await openLog(tester);
    await tester.tap(chip('Mia'));
    await tester.pump();
    await tester.tap(chip('Rex'));
    await tester.pump();

    await tester.tap(historyButton);
    await tester.pumpAndSettle();

    expect(tester.widget<PetHistoryScreen>(find.byType(PetHistoryScreen)).pet.name, 'Rex');
  });

  testWidgets('"History" is disabled while no pet is picked', (tester) async {
    await addPet(tester, 'Rex');
    await addPet(tester, 'Mia');
    await openLog(tester);

    expect(tester.widget<TextButton>(historyButton).onPressed, isNull);
    await tester.tap(chip('Rex'));
    await tester.pump();
    expect(tester.widget<TextButton>(historyButton).onPressed, isNotNull);
  });

  testWidgets('001-FR-004: the menu\'s "My event types" opens My event types', (tester) async {
    await addPet(tester, 'Rex');
    await openLog(tester);

    await tester.tap(find.byTooltip('Menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('My event types'));
    await tester.pumpAndSettle();

    expect(find.byType(MyEventTypesScreen), findsOneWidget);
  });

  testWidgets('the log screen is accessible with one pet and with several', (tester) async {
    await addPet(tester, 'Rex');
    await openLog(tester);
    await expectAccessible(tester);

    await addPet(tester, 'Mia');
    await tester.pumpAndSettle();
    expect(find.byType(PetChoices), findsOneWidget);
    await expectAccessible(tester);
  });

  group('when a read fails', () {
    late ControlledPets pets;
    late ControlledTypes types;
    final vomiting = builtInEventTypes.firstWhere((type) => type.name == 'Vomiting');

    setUp(() {
      pets = ControlledPets();
      types = ControlledTypes();
    });

    final key = GlobalKey();

    Widget screenWith(ControlledPets pets, ControlledTypes types) => AppScope(
      pets: pets,
      eventTypes: types,
      events: app.events,
      child: MaterialApp(
        home: LogScreen(key: key, clock: () => now),
      ),
    );

    Future<void> openControlled(WidgetTester tester) async {
      await tester.pumpWidget(screenWith(pets, types));
      pets.send([pet('a', 'Mia'), pet('b', 'Rex')]);
      types.send([vomiting]);
      await tester.pumpAndSettle();
    }

    void expectReportedWithout(WidgetTester tester, String name) {
      final error = tester.takeException();
      expect(error, isNotNull);
      expect(error.toString(), isNot(contains(name)));
    }

    testWidgets('001-FR-007: the pets read failing → the pets and the pick stay, and the error '
        'is reported without the pet\'s name', (tester) async {
      await openControlled(tester);
      await tester.tap(chip('Rex'));
      await tester.pump();

      pets.fail(Exception('SELECT FROM pets failed for Rex'));
      await tester.pumpAndSettle();

      expectReportedWithout(tester, 'Rex');
      expect(chip('Mia'), findsOneWidget);
      expect(isPicked(tester, 'Rex'), isTrue);
      expect(tester.widget<TextButton>(historyButton).onPressed, isNotNull);
    });

    testWidgets('other repositories → what the earlier ones read afterwards is not shown', (
      tester,
    ) async {
      await openControlled(tester);
      final otherPets = ControlledPets();
      final otherTypes = ControlledTypes();
      await tester.pumpWidget(screenWith(otherPets, otherTypes));
      otherPets.send([pet('c', 'Bo'), pet('d', 'Ivy')]);
      otherTypes.send([builtInEventTypes.firstWhere((type) => type.name == 'Seizure')]);
      await tester.pumpAndSettle();

      pets.send([pet('a', 'Mia'), pet('b', 'Rex')]);
      types.send([vomiting]);
      await tester.pumpAndSettle();

      expect(chip('Bo'), findsOneWidget);
      expect(chip('Rex'), findsNothing);
      expect(typeButton('Seizure'), findsOneWidget);
      expect(typeButton('Vomiting'), findsNothing);
    });

    testWidgets('the types read failing → the type buttons stay, and the error is reported '
        'without the type\'s name', (tester) async {
      await openControlled(tester);

      types.fail(Exception('SELECT FROM event_types failed for Ear shaking'));
      await tester.pumpAndSettle();

      expectReportedWithout(tester, 'Ear shaking');
      expect(typeButton('Vomiting'), findsOneWidget);
    });
  });
}
