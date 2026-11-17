import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_health_tracker/data/repositories.dart';
import 'package:pet_health_tracker/domain/medical_event.dart';
import 'package:pet_health_tracker/domain/pet.dart';
import 'package:pet_health_tracker/ui/app_scope.dart';
import 'package:pet_health_tracker/ui/history/event_tile.dart';
import 'package:pet_health_tracker/ui/history/pet_history_screen.dart';
import 'package:pet_health_tracker/ui/history/type_summary.dart';

import '../../support/robot.dart';
import '../../support/screen_checks.dart';
import '../../support/test_app.dart';

/// A [PetRepository] whose `watch` sends the pets and errors the test sends;
/// anything else is unused by the screen.
class ControlledPets implements PetRepository {
  final _pet = StreamController<Pet?>.broadcast();

  void send(Pet? pet) => _pet.add(pet);

  void fail(Object error) => _pet.addError(error, StackTrace.current);

  @override
  Stream<Pet?> watch(String id) => _pet.stream;

  @override
  Never noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

/// An [EventRepository] whose `watchForPet` sends the lists and errors the
/// test sends; anything else is unused by the screen.
class ControlledEvents implements EventRepository {
  final _events = StreamController<List<MedicalEvent>>.broadcast();

  void send(List<MedicalEvent> events) => _events.add(events);

  void fail(Object error) => _events.addError(error, StackTrace.current);

  @override
  Stream<List<MedicalEvent>> watchForPet(String petId) => _events.stream;

  @override
  Never noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

/// The texts of the event tiles, top to bottom, one string per tile.
List<String> tileTexts(WidgetTester tester) => [
  for (final tile in find.byType(EventTile).evaluate())
    tester
        .widgetList<Text>(
          find.descendant(of: find.byWidget(tile.widget), matching: find.byType(Text)),
        )
        .map((text) => text.data)
        .join('\n'),
];

/// The local [pets], except that `setArchived` fails with an error naming
/// the pet, as sqflite's `DatabaseException` lists a statement's arguments.
class FailingArchive implements PetRepository {
  FailingArchive(this.pets);

  final PetRepository pets;

  @override
  Stream<Pet?> watch(String id) => pets.watch(id);

  @override
  Future<void> setArchived(String id, bool archived) =>
      Future.error(Exception('UPDATE pets failed for Rex'));

  @override
  Never noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

/// The local [pets], except that `setArchived` waits for [done] before
/// writing.
class SlowArchive implements PetRepository {
  SlowArchive(this.pets);

  final PetRepository pets;
  final done = Completer<void>();

  @override
  Stream<Pet?> watch(String id) => pets.watch(id);

  @override
  Future<void> setArchived(String id, bool archived) async {
    await done.future;
    await pets.setArchived(id, archived);
  }

  @override
  Never noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

Finder get archiveButton => find.widgetWithText(TextButton, 'Archive');

Finder get restoreButton => find.widgetWithText(TextButton, 'Restore');

String title(WidgetTester tester) => tester
    .widget<Text>(find.descendant(of: find.byType(AppBar), matching: find.byType(Text)).first)
    .data!;

void main() {
  late TestApp app;

  /// Noon on Nov 14, 2026 in the tests' America/Chicago time zone.
  final now = DateTime(2026, 11, 14, 12);

  setUp(() async => app = await openTestApp(now: now));

  Future<Pet> addPet(WidgetTester tester, String name, {TestApp? to}) async =>
      (await tester.runAsync(() => (to ?? app).pets.add(name: name, species: Species.dog)))!;

  Future<MedicalEvent> log(
    WidgetTester tester,
    Pet pet,
    TypeChoice type,
    DateTime at, {
    Map<String, Object> details = const {},
    String? note,
    TestApp? to,
  }) async => (await tester.runAsync(
    () => (to ?? app).events.log(
      petId: pet.id,
      type: type,
      occurredAt: at,
      details: details,
      note: note,
    ),
  ))!;

  Widget screenIn({required Pet pet, PetRepository? pets, EventRepository? events, Key? key}) =>
      AppScope(
        pets: pets ?? app.pets,
        eventTypes: app.eventTypes,
        events: events ?? app.events,
        child: MaterialApp(
          home: PetHistoryScreen(key: key, pet: pet, clock: app.clock),
        ),
      );

  Future<void> openHistory(
    WidgetTester tester,
    Pet pet, {
    PetRepository? pets,
    EventRepository? events,
  }) async {
    await tester.pumpWidget(screenIn(pet: pet, pets: pets, events: events));
    await tester.pumpAndSettle();
  }

  testWidgets('001-US2-S1 001-FR-008: the pet\'s name as the title, then its events newest '
      'first, each with date, time, type, details and note', (tester) async {
    final rex = await addPet(tester, 'Rex');
    await log(tester, rex, ExistingType('vomiting'), DateTime(2026, 11, 10, 8));
    await log(
      tester,
      rex,
      ExistingType('seizure'),
      DateTime(2026, 11, 13, 21, 30),
      details: {'duration': 135},
      note: 'After dinner',
    );
    await log(tester, rex, ExistingType('sneezing'), DateTime(2026, 11, 12, 7, 15));

    await openHistory(tester, rex);

    expect(title(tester), 'Rex');
    expect(tileTexts(tester), [
      'Seizure\nNov 13, 2026 9:30\u202fPM\nHow long it lasted: 2 min 15 s\nAfter dinner',
      'Sneezing\nNov 12, 2026 7:15\u202fAM',
      'Vomiting\nNov 10, 2026 8:00\u202fAM',
    ]);
  });

  testWidgets('001-US2-S1: only this pet\'s events are listed', (tester) async {
    final rex = await addPet(tester, 'Rex');
    final mia = await addPet(tester, 'Mia');
    await log(tester, rex, ExistingType('vomiting'), DateTime(2026, 11, 10, 8));
    await log(tester, mia, ExistingType('seizure'), DateTime(2026, 11, 11, 8));

    await openHistory(tester, rex);

    expect(tileTexts(tester), ['Vomiting\nNov 10, 2026 8:00\u202fAM']);
  });

  testWidgets('001-US2-S2 001-US2-S4: each event shows the time since the previous one of its '
      'type, over the pet\'s whole history; the first of a type shows none', (tester) async {
    final rex = await addPet(tester, 'Rex');
    await log(tester, rex, ExistingType('vomiting'), DateTime(2025, 11, 1, 8));
    await log(tester, rex, ExistingType('vomiting'), DateTime(2026, 11, 11, 8));
    await log(tester, rex, ExistingType('seizure'), DateTime(2026, 11, 12, 8));
    await log(tester, rex, ExistingType('vomiting'), DateTime(2026, 11, 13, 8));

    await openHistory(tester, rex);

    expect(tileTexts(tester), [
      'Vomiting\nNov 13, 2026 8:00\u202fAM\n2 days since the previous one',
      'Seizure\nNov 12, 2026 8:00\u202fAM',
      'Vomiting\nNov 11, 2026 8:00\u202fAM\n375 days since the previous one',
      'Vomiting\nNov 1, 2025 8:00\u202fAM',
    ]);
  });

  testWidgets('001-SC-003: how long since the last one and how often show at the top, above '
      'the events', (tester) async {
    final rex = await addPet(tester, 'Rex');
    await log(tester, rex, ExistingType('vomiting'), DateTime(2026, 11, 10, 12));
    await log(tester, rex, ExistingType('vomiting'), DateTime(2026, 11, 14, 9));

    await openHistory(tester, rex);

    final summary = find.byType(TypeSummaryList);
    expect(find.descendant(of: summary, matching: find.text('2 times')), findsOneWidget);
    expect(
      find.descendant(of: summary, matching: find.text('about every 3.8 days')),
      findsOneWidget,
    );
    expect(find.descendant(of: summary, matching: find.text('last 3 hours ago')), findsOneWidget);
    expect(
      tester.getBottomLeft(summary).dy,
      lessThanOrEqualTo(tester.getTopLeft(find.byType(EventTile).first).dy),
    );
  });

  testWidgets('001-FR-008: a removed custom type still shows its name', (tester) async {
    final rex = await addPet(tester, 'Rex');
    final event = await log(tester, rex, NewTypeName('Ear shaking'), DateTime(2026, 11, 13, 8));
    await tester.runAsync(() => app.eventTypes.remove(event.typeId));

    await openHistory(tester, rex);

    expect(tileTexts(tester), ['Ear shaking\nNov 13, 2026 8:00\u202fAM']);
    expect(
      find.descendant(of: find.byType(TypeSummaryList), matching: find.text('Ear shaking')),
      findsOneWidget,
    );
  });

  testWidgets('001-FR-008: a new event shows in the open history', (tester) async {
    final rex = await addPet(tester, 'Rex');
    await openHistory(tester, rex);
    expect(find.text('Nothing logged in this period'), findsOneWidget);
    expect(find.byType(EventTile), findsNothing);

    await log(tester, rex, ExistingType('vomiting'), DateTime(2026, 11, 13, 8));
    await tester.pumpAndSettle();

    expect(tileTexts(tester), ['Vomiting\nNov 13, 2026 8:00\u202fAM']);
  });

  testWidgets('001-US3-S2: "Edit pet" changes the name; the title follows and the events stay', (
    tester,
  ) async {
    final rex = await addPet(tester, 'Rex');
    await log(tester, rex, ExistingType('vomiting'), DateTime(2026, 11, 13, 8));
    await openHistory(tester, rex);

    await tester.tap(find.widgetWithText(TextButton, 'Edit pet'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Edit pet'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Rex'), findsOneWidget);
    await Robot(tester).addPet('Max', Species.cat);

    expect(find.byType(PetHistoryScreen), findsOneWidget);
    expect(title(tester), 'Max');
    expect(tileTexts(tester), ['Vomiting\nNov 13, 2026 8:00\u202fAM']);
  });

  Future<Pet?> stored(WidgetTester tester, Pet pet) =>
      tester.runAsync<Pet?>(() => app.pets.watch(pet.id).first);

  testWidgets('001-US3-S3 001-FR-015: "Archive" archives the pet, which then shows "Archived" '
      'under its title and "Restore", and keeps its history', (tester) async {
    final rex = await addPet(tester, 'Rex');
    await log(tester, rex, ExistingType('vomiting'), DateTime(2026, 11, 13, 8));
    await openHistory(tester, rex);
    expect(find.text('Archived'), findsNothing);
    expect(restoreButton, findsNothing);

    await tester.tap(archiveButton);
    await tester.pumpAndSettle();

    expect((await stored(tester, rex))!.archived, isTrue);
    expect(find.byType(PetHistoryScreen), findsOneWidget);
    expect(title(tester), 'Rex');
    expect(find.text('Archived'), findsOneWidget);
    expect(archiveButton, findsNothing);
    expect(restoreButton, findsOneWidget);
    expect(tileTexts(tester), ['Vomiting\nNov 13, 2026 8:00\u202fAM']);
  });

  testWidgets('001-US3-S4: "Restore" makes an archived pet active again, with its history', (
    tester,
  ) async {
    final rex = await addPet(tester, 'Rex');
    await log(tester, rex, ExistingType('vomiting'), DateTime(2026, 11, 13, 8));
    await tester.runAsync(() => app.pets.setArchived(rex.id, true));
    await openHistory(tester, rex.copyWith(archived: true));
    expect(find.text('Archived'), findsOneWidget);

    await tester.tap(restoreButton);
    await tester.pumpAndSettle();

    expect((await stored(tester, rex))!.archived, isFalse);
    expect(find.text('Archived'), findsNothing);
    expect(restoreButton, findsNothing);
    expect(archiveButton, findsOneWidget);
    expect(tileTexts(tester), ['Vomiting\nNov 13, 2026 8:00\u202fAM']);
  });

  testWidgets('a failed archive is reported without the pet\'s name, and "Archive" works again', (
    tester,
  ) async {
    final rex = await addPet(tester, 'Rex');
    await openHistory(tester, rex, pets: FailingArchive(app.pets));

    final errors = <Object>[];
    await runZonedGuarded(() async {
      await tester.tap(archiveButton);
      await tester.pumpAndSettle();
    }, (error, _) => errors.add(error));
    await tester.pumpAndSettle();

    expect(errors, hasLength(1));
    expect(errors.single.toString(), isNot(contains('Rex')));
    expect(find.text('Archived'), findsNothing);
    expect(tester.widget<TextButton>(archiveButton).onPressed, isNotNull);
  });

  testWidgets('"Archive" is disabled while archiving, and "Restore" is enabled once done', (
    tester,
  ) async {
    final rex = await addPet(tester, 'Rex');
    final pets = SlowArchive(app.pets);
    await openHistory(tester, rex, pets: pets);

    await tester.tap(archiveButton);
    await tester.pump();
    expect(tester.widget<TextButton>(archiveButton).onPressed, isNull);

    pets.done.complete();
    await tester.pumpAndSettle();

    expect(tester.widget<TextButton>(restoreButton).onPressed, isNotNull);
  });

  testWidgets('an archived pet\'s history is accessible', (tester) async {
    final rex = await addPet(tester, 'Rex');
    await log(tester, rex, ExistingType('vomiting'), DateTime(2026, 11, 13, 8));
    await tester.runAsync(() => app.pets.setArchived(rex.id, true));
    await openHistory(tester, rex.copyWith(archived: true));

    await expectAccessible(tester);
  });

  testWidgets('a pet that can\'t be found keeps the title', (tester) async {
    final pets = ControlledPets();
    final rex = Pet(id: 'rex', name: 'Rex', species: Species.dog, createdAt: now.toUtc());
    await openHistory(tester, rex, pets: pets);

    pets.send(null);
    await tester.pumpAndSettle();

    expect(title(tester), 'Rex');
  });

  testWidgets('a failed read of the pet is reported without its name and keeps the title', (
    tester,
  ) async {
    final pets = ControlledPets();
    final rex = await addPet(tester, 'Rex');
    await openHistory(tester, rex, pets: pets);

    pets.fail(Exception('SELECT FROM pets failed for Rex'));
    await tester.pumpAndSettle();

    final error = tester.takeException();
    expect(error, isNotNull);
    expect(error.toString(), isNot(contains('Rex')));
    expect(title(tester), 'Rex');
  });

  testWidgets('a failed read before any events says the history couldn\'t be loaded '
      '(D-025), without the read\'s message, until the events are read', (tester) async {
    final events = ControlledEvents();
    final rex = await addPet(tester, 'Rex');
    final logged = await log(tester, rex, ExistingType('vomiting'), DateTime(2026, 11, 13, 8));
    await openHistory(tester, rex, events: events);

    events.fail(Exception('SELECT FROM events failed for Rex'));
    await tester.pumpAndSettle();

    final error = tester.takeException();
    expect(error, isNotNull);
    expect(error.toString(), isNot(contains('Rex')));
    expect(find.text(PetHistoryScreen.loadFailed), findsOneWidget);
    expect(title(tester), 'Rex');

    events.send([logged]);
    await tester.pumpAndSettle();
    expect(find.text(PetHistoryScreen.loadFailed), findsNothing);
    expect(tileTexts(tester), ['Vomiting\nNov 13, 2026 8:00\u202fAM']);
  });

  testWidgets('a failed read after the events keeps them shown (D-025)', (tester) async {
    final events = ControlledEvents();
    final rex = await addPet(tester, 'Rex');
    final logged = await log(tester, rex, ExistingType('vomiting'), DateTime(2026, 11, 13, 8));
    await openHistory(tester, rex, events: events);
    events.send([logged]);
    await tester.pumpAndSettle();

    events.fail(Exception('SELECT FROM events failed for Rex'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNotNull);
    expect(find.text(PetHistoryScreen.loadFailed), findsNothing);
    expect(tileTexts(tester), ['Vomiting\nNov 13, 2026 8:00\u202fAM']);
  });

  testWidgets('other repositories → the pet and events in them', (tester) async {
    final rex = await addPet(tester, 'Rex');
    await log(tester, rex, ExistingType('vomiting'), DateTime(2026, 11, 13, 8));
    final other = (await tester.runAsync(() => openTestApp(now: now)))!;
    final bo = await addPet(tester, 'Bo', to: other);
    expect(bo.id, rex.id);
    await log(tester, bo, ExistingType('seizure'), DateTime(2026, 11, 12, 8), to: other);
    final key = GlobalKey();
    await tester.pumpWidget(screenIn(pet: rex, key: key));
    await tester.pumpAndSettle();

    await tester.pumpWidget(
      AppScope(
        pets: other.pets,
        eventTypes: other.eventTypes,
        events: other.events,
        child: MaterialApp(
          home: PetHistoryScreen(key: key, pet: rex, clock: app.clock),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(title(tester), 'Bo');
    expect(tileTexts(tester), ['Seizure\nNov 12, 2026 8:00\u202fAM']);
  });

  testWidgets('the pet history is accessible', (tester) async {
    final rex = await addPet(tester, 'Rex');
    await log(tester, rex, ExistingType('vomiting'), DateTime(2026, 11, 10, 8));
    await log(
      tester,
      rex,
      ExistingType('seizure'),
      DateTime(2026, 11, 13, 21, 30),
      details: {'duration': 135},
      note: 'After dinner',
    );
    await log(tester, rex, ExistingType('vomiting'), DateTime(2026, 11, 13, 8));
    await openHistory(tester, rex);

    await expectAccessible(tester);
  });
}
