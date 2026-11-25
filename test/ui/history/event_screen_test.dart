import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_health_tracker/data/repositories.dart';
import 'package:pet_health_tracker/domain/built_in_event_types.dart';
import 'package:pet_health_tracker/domain/event_type.dart';
import 'package:pet_health_tracker/domain/medical_event.dart';
import 'package:pet_health_tracker/domain/pet.dart';
import 'package:pet_health_tracker/ui/app_scope.dart';
import 'package:pet_health_tracker/ui/history/event_screen.dart';
import 'package:pet_health_tracker/ui/history/event_tile.dart';
import 'package:pet_health_tracker/ui/history/pet_history_screen.dart';
import 'package:pet_health_tracker/ui/history/type_summary.dart';
import 'package:pet_health_tracker/ui/log/pet_choices.dart';

import '../../support/pickers.dart';
import '../../support/screen_checks.dart';
import '../../support/test_app.dart';

/// The local [events], except that `update` fails with an error holding the
/// note, as sqflite's `DatabaseException` lists a statement's arguments, and
/// `delete` fails too.
class FailingUpdate implements EventRepository {
  FailingUpdate(this.events);

  final EventRepository events;

  @override
  Stream<List<MedicalEvent>> watchForPet(String petId) => events.watchForPet(petId);

  @override
  Future<void> update(
    String id, {
    required String petId,
    required TypeChoice type,
    required DateTime occurredAt,
    required Map<String, Object> details,
    String? note,
  }) => Future.error(Exception('UPDATE events failed for $note'));

  @override
  Future<void> delete(String id) => Future.error(Exception('DELETE FROM events failed'));

  @override
  Never noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

/// The local [events], except that `update` and `delete` wait for [done]
/// before writing.
class SlowWrites implements EventRepository {
  SlowWrites(this.events);

  final EventRepository events;
  final done = Completer<void>();

  @override
  Stream<List<MedicalEvent>> watchForPet(String petId) => events.watchForPet(petId);

  @override
  Future<void> update(
    String id, {
    required String petId,
    required TypeChoice type,
    required DateTime occurredAt,
    required Map<String, Object> details,
    String? note,
  }) async {
    await done.future;
    await events.update(
      id,
      petId: petId,
      type: type,
      occurredAt: occurredAt,
      details: details,
      note: note,
    );
  }

  @override
  Future<void> delete(String id) async {
    await done.future;
    await events.delete(id);
  }

  @override
  Never noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

/// A [PetRepository] whose active pets can't be read, with an error naming a
/// pet; anything else is unused by the event screen.
class UnreadablePets implements PetRepository {
  @override
  Stream<List<Pet>> watchActive() => Stream.error(Exception('SELECT failed for Mia'));

  @override
  Never noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

/// An [EventTypeRepository] whose offered types can't be read, with an error
/// naming a type; anything else is unused by the event screen.
class UnreadableTypes implements EventTypeRepository {
  @override
  Stream<List<EventType>> watchOffered() => Stream.error(Exception('SELECT failed for Limping'));

  @override
  Never noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

/// A [PetRepository] whose active pets are the lists the test sends;
/// anything else is unused by the event screen.
class ControlledPets implements PetRepository {
  final _active = StreamController<List<Pet>>.broadcast();

  void send(List<Pet> active) => _active.add(active);

  @override
  Stream<List<Pet>> watchActive() => _active.stream;

  @override
  Never noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

/// An [EventTypeRepository] whose offered types are the lists the test
/// sends; anything else is unused by the event screen.
class ControlledTypes implements EventTypeRepository {
  final _offered = StreamController<List<EventType>>.broadcast();

  void send(List<EventType> offered) => _offered.add(offered);

  @override
  Stream<List<EventType>> watchOffered() => _offered.stream;

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

/// Finds [text] in the history's summary.
Finder inSummary(String text) =>
    find.descendant(of: find.byType(TypeSummaryList), matching: find.text(text));

Finder get saveButton => find.widgetWithText(FilledButton, 'Save');

Finder get deleteButton => find.widgetWithText(TextButton, 'Delete');

Finder get typeField => find.byType(DropdownButtonFormField<String>);

/// The id of the type picked in the "Type" dropdown.
String? pickedTypeId(WidgetTester tester) =>
    tester.widget<DropdownButton<String>>(find.byType(DropdownButton<String>)).value;

/// The pet chips, each as its name and whether it is picked.
Map<String, bool> petChips(WidgetTester tester) => {
  for (final chip in tester.widgetList<ChoiceChip>(
    find.descendant(of: find.byType(PetChoices), matching: find.byType(ChoiceChip)),
  ))
    if (chip.label case Text(:final data?)) data: chip.selected,
};

void main() {
  late TestApp app;

  /// Noon on Nov 14, 2026 in the tests' America/Chicago time zone.
  final now = DateTime(2026, 11, 14, 12);

  setUp(() async => app = await openTestApp(now: now));

  Future<Pet> addPet(WidgetTester tester, String name) async =>
      (await tester.runAsync(() => app.pets.add(name: name, species: Species.dog)))!;

  Future<MedicalEvent> log(
    WidgetTester tester,
    Pet pet,
    TypeChoice type,
    DateTime at, {
    Map<String, Object> details = const {},
    String? note,
  }) async => (await tester.runAsync(
    () => app.events.log(petId: pet.id, type: type, occurredAt: at, details: details, note: note),
  ))!;

  Future<void> openHistory(WidgetTester tester, Pet pet, {EventRepository? events}) async {
    await tester.pumpWidget(
      AppScope(
        pets: app.pets,
        eventTypes: app.eventTypes,
        events: events ?? app.events,
        child: MaterialApp(
          home: PetHistoryScreen(key: ValueKey(pet.id), pet: pet, clock: app.clock),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// In the open history, taps the event tile whose text contains [text].
  Future<void> openEvent(WidgetTester tester, String text) async {
    await tester.tap(
      find.ancestor(of: find.textContaining(text), matching: find.byType(EventTile)),
    );
    await tester.pumpAndSettle();
  }

  Future<void> pickType(WidgetTester tester, String name) async {
    await tester.tap(typeField);
    await tester.pumpAndSettle();
    await tester.tap(find.text(name).last);
    await tester.pumpAndSettle();
  }

  Future<void> save(WidgetTester tester) async {
    await tester.ensureVisible(saveButton);
    await tester.tap(saveButton);
    await tester.pumpAndSettle();
  }

  testWidgets('tapping an event in the history opens "Event", filled in with its pet, type, '
      'time, details and note', (tester) async {
    final rex = await addPet(tester, 'Rex');
    await addPet(tester, 'Mia');
    await log(
      tester,
      rex,
      ExistingType('seizure'),
      DateTime(2026, 11, 13, 21, 30),
      details: {'kind': 'focal', 'duration': 135},
      note: 'After dinner',
    );
    await openHistory(tester, rex);

    await openEvent(tester, 'Seizure');

    expect(find.byType(EventScreen), findsOneWidget);
    expect(find.descendant(of: find.byType(AppBar), matching: find.text('Event')), findsOneWidget);
    expect(petChips(tester), {'Mia': false, 'Rex': true});
    expect(pickedTypeId(tester), 'seizure');
    expect(find.widgetWithText(ChoiceChip, 'Focal'), findsOneWidget);
    expect(tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Focal')).selected, isTrue);
    expect(find.text('Nov 13, 2026 9:30 PM'), findsOneWidget);
    expect(find.widgetWithText(TextField, '2'), findsOneWidget);
    expect(find.widgetWithText(TextField, '15'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'After dinner'), findsOneWidget);
    await expectAccessible(tester);
  });

  testWidgets('001-US1-S8 001-FR-011: details and a note added later are saved, and "Save" '
      'returns to the history, which shows them', (tester) async {
    final rex = await addPet(tester, 'Rex');
    await log(tester, rex, ExistingType('seizure'), DateTime(2026, 11, 13, 21, 30));
    await openHistory(tester, rex);
    await openEvent(tester, 'Seizure');

    await tester.tap(find.widgetWithText(ChoiceChip, 'Grand mal'));
    await tester.enterText(find.widgetWithText(TextField, 'Minutes'), '3');
    await tester.enterText(find.widgetWithText(TextField, 'Note (optional)'), 'Woke up confused');
    await save(tester);

    expect(find.byType(EventScreen), findsNothing);
    expect(tileTexts(tester), [
      'Seizure\nNov 13, 2026 9:30 PM\nKind: Grand mal\nHow long it lasted: 3 min\n'
          'Woke up confused',
    ]);
  });

  testWidgets('a duration under a minute fills in only "Seconds", and whole minutes only '
      '"Minutes"; saved unchanged, each reads as before', (tester) async {
    final rex = await addPet(tester, 'Rex');
    await log(
      tester,
      rex,
      ExistingType('coughing'),
      DateTime(2026, 11, 12, 8),
      details: {'duration': 45},
    );
    await log(
      tester,
      rex,
      ExistingType('seizure'),
      DateTime(2026, 11, 13, 8),
      details: {'duration': 180},
    );
    await openHistory(tester, rex);
    String field(String label) =>
        tester.widget<TextField>(find.widgetWithText(TextField, label)).controller!.text;

    await openEvent(tester, 'Coughing');
    expect((field('Minutes'), field('Seconds')), ('', '45'));
    await save(tester);
    await openEvent(tester, 'Seizure');
    expect((field('Minutes'), field('Seconds')), ('3', ''));
    await save(tester);

    expect(tileTexts(tester), [
      'Seizure\nNov 13, 2026 8:00 AM\nHow long it lasted: 3 min',
      'Coughing\nNov 12, 2026 8:00 AM\nHow long it lasted: 45 s',
    ]);
  });

  testWidgets('001-US1-S8: details and a note can be changed and cleared', (tester) async {
    final rex = await addPet(tester, 'Rex');
    await log(
      tester,
      rex,
      ExistingType('seizure'),
      DateTime(2026, 11, 13, 21, 30),
      details: {'kind': 'focal', 'duration': 135},
      note: 'After dinner',
    );
    await openHistory(tester, rex);
    await openEvent(tester, 'Seizure');

    await tester.tap(find.widgetWithText(ChoiceChip, 'Focal'));
    await tester.enterText(find.widgetWithText(TextField, '15'), '30');
    await tester.enterText(find.widgetWithText(TextField, 'After dinner'), '');
    await save(tester);

    expect(tileTexts(tester), ['Seizure\nNov 13, 2026 9:30 PM\nHow long it lasted: 2 min 30 s']);
  });

  testWidgets('001-US4-S1: a changed time moves the event, and the gaps and summary follow', (
    tester,
  ) async {
    final rex = await addPet(tester, 'Rex');
    await log(tester, rex, ExistingType('vomiting'), DateTime(2026, 11, 10, 8));
    await log(tester, rex, ExistingType('vomiting'), DateTime(2026, 11, 12, 8));
    await openHistory(tester, rex);
    expect(inSummary('about every 2.0 days'), findsOneWidget);

    await openEvent(tester, 'Nov 10');
    await openPickers(tester);
    await pickDay(tester, 6);
    await pickTime(tester, 8, 0, 'AM');
    await save(tester);

    expect(tileTexts(tester), [
      'Vomiting\nNov 12, 2026 8:00 AM\n6 days since the previous one',
      'Vomiting\nNov 6, 2026 8:00 AM',
    ]);
    expect(inSummary('about every 6.0 days'), findsOneWidget);
    expect(inSummary('2 times'), findsOneWidget);
  });

  testWidgets('001-US4-S1: a changed pet moves the event to that pet\'s history', (tester) async {
    final rex = await addPet(tester, 'Rex');
    final mia = await addPet(tester, 'Mia');
    await log(tester, rex, ExistingType('vomiting'), DateTime(2026, 11, 10, 8));
    await openHistory(tester, rex);
    await openEvent(tester, 'Vomiting');

    await tester.tap(find.widgetWithText(ChoiceChip, 'Mia'));
    await save(tester);

    expect(tileTexts(tester), isEmpty);
    await openHistory(tester, mia);
    expect(tileTexts(tester), ['Vomiting\nNov 10, 2026 8:00 AM']);
  });

  testWidgets('001-US4-S1: a changed type keeps only the details its questions share, and the '
      'summary follows', (tester) async {
    final rex = await addPet(tester, 'Rex');
    await log(
      tester,
      rex,
      ExistingType('seizure'),
      DateTime(2026, 11, 13, 21, 30),
      details: {'kind': 'focal', 'duration': 135},
    );
    await openHistory(tester, rex);
    await openEvent(tester, 'Seizure');

    await pickType(tester, 'Coughing');

    expect(find.widgetWithText(ChoiceChip, 'Focal'), findsNothing);
    expect(find.widgetWithText(TextField, '15'), findsOneWidget);
    await save(tester);
    expect(tileTexts(tester), ['Coughing\nNov 13, 2026 9:30 PM\nHow long it lasted: 2 min 15 s']);
    expect(inSummary('Coughing'), findsOneWidget);
    expect(inSummary('Seizure'), findsNothing);
  });

  testWidgets('001-FR-015: an archived pet\'s event offers the active pets and its own pet, and '
      'no other archived pet', (tester) async {
    final rex = await addPet(tester, 'Rex');
    await addPet(tester, 'Mia');
    final bo = await addPet(tester, 'Bo');
    await log(tester, rex, ExistingType('vomiting'), DateTime(2026, 11, 10, 8));
    await tester.runAsync(() => app.pets.setArchived(rex.id, true));
    await tester.runAsync(() => app.pets.setArchived(bo.id, true));
    await openHistory(tester, rex.copyWith(archived: true));

    await openEvent(tester, 'Vomiting');

    expect(petChips(tester), {'Mia': false, 'Rex': true});
    await save(tester);
    expect(tileTexts(tester), ['Vomiting\nNov 10, 2026 8:00 AM']);
  });

  testWidgets('an event of a removed type offers that type with the offered ones', (tester) async {
    final rex = await addPet(tester, 'Rex');
    final event = await log(tester, rex, NewTypeName('Limping'), DateTime(2026, 11, 10, 8));
    await tester.runAsync(() => app.eventTypes.remove(event.typeId));
    await openHistory(tester, rex);
    await openEvent(tester, 'Limping');

    expect(pickedTypeId(tester), event.typeId);
    await pickType(tester, 'Sneezing');
    await pickType(tester, 'Limping');
    await save(tester);

    expect(tileTexts(tester), ['Limping\nNov 10, 2026 8:00 AM']);
  });

  Future<void> openEventScreen(
    WidgetTester tester,
    MedicalEvent event,
    Pet pet, {
    PetRepository? pets,
    EventTypeRepository? eventTypes,
    Key? key,
  }) async {
    final type = (await tester.runAsync(() => app.eventTypes.byId(event.typeId)))!;
    await tester.pumpWidget(
      AppScope(
        pets: pets ?? app.pets,
        eventTypes: eventTypes ?? app.eventTypes,
        events: app.events,
        child: MaterialApp(
          home: EventScreen(key: key, event: event, pet: pet, type: type, clock: app.clock),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Opens the "Type" dropdown and returns the names in its menu, then closes
  /// it by picking Vomiting.
  Future<List<String>> offeredTypeNames(WidgetTester tester) async {
    await tester.tap(typeField);
    await tester.pumpAndSettle();
    final names = [
      for (final item in tester.widgetList<DropdownMenuItem<String>>(
        find.byType(DropdownMenuItem<String>),
      ))
        if (item.child case Text(:final data?)) data,
    ];
    await tester.tap(find.text('Vomiting').last);
    await tester.pumpAndSettle();
    return names.toSet().toList();
  }

  testWidgets('other repositories → only the event\'s own pet and type are offered until the new '
      'ones\' lists arrive, then theirs', (tester) async {
    final rex = await addPet(tester, 'Rex');
    await addPet(tester, 'Mia');
    final event = await log(tester, rex, ExistingType('vomiting'), DateTime(2026, 11, 10, 8));
    final key = GlobalKey();
    await openEventScreen(tester, event, rex, key: key);
    expect(petChips(tester), {'Mia': false, 'Rex': true});

    final pets = ControlledPets();
    final types = ControlledTypes();
    await openEventScreen(tester, event, rex, pets: pets, eventTypes: types, key: key);

    expect(petChips(tester), {'Rex': true});
    expect(await offeredTypeNames(tester), ['Vomiting']);

    final bo = Pet(id: 'bo', name: 'Bo', species: Species.cat, createdAt: DateTime.utc(2026));
    pets.send([rex, bo]);
    types.send(
      builtInEventTypes.where((type) => {'vomiting', 'seizure'}.contains(type.id)).toList(),
    );
    await tester.pumpAndSettle();

    expect(petChips(tester), {'Rex': true, 'Bo': false});
    expect(await offeredTypeNames(tester), ['Vomiting', 'Seizure']);
  });

  testWidgets('other repositories → a pet and type picked from the earlier ones go back to the '
      'event\'s own, and "Save" keeps only the details its questions share', (tester) async {
    final rex = await addPet(tester, 'Rex');
    await addPet(tester, 'Mia');
    final event = await log(tester, rex, ExistingType('coughing'), DateTime(2026, 11, 10, 8));
    final coughing = (await tester.runAsync(() => app.eventTypes.byId('coughing')))!;
    final navigator = GlobalKey<NavigatorState>();
    Widget appWith(PetRepository pets, EventTypeRepository types) => AppScope(
      pets: pets,
      eventTypes: types,
      events: app.events,
      child: MaterialApp(navigatorKey: navigator, home: const Scaffold()),
    );
    await tester.pumpWidget(appWith(app.pets, app.eventTypes));
    unawaited(
      navigator.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => EventScreen(event: event, pet: rex, type: coughing, clock: app.clock),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(PetChoices), matching: find.text('Mia')));
    await tester.pump();
    await pickType(tester, 'Seizure');
    await tester.ensureVisible(find.text('Grand mal'));
    await tester.tap(find.text('Grand mal'));
    await tester.enterText(find.widgetWithText(TextField, 'Minutes'), '2');
    await tester.pump();
    expect(petChips(tester), {'Mia': true, 'Rex': false});

    await tester.pumpWidget(appWith(ControlledPets(), ControlledTypes()));
    await tester.pumpAndSettle();

    expect(petChips(tester), {'Rex': true});
    expect(pickedTypeId(tester), 'coughing');
    expect(find.text('Kind'), findsNothing);
    await save(tester);
    final saved = (await tester.runAsync(() => app.events.watchForPet(rex.id).first))!;
    expect(saved.map((event) => event.typeId), ['coughing']);
    expect(saved.single.details, {'duration': 120});
  });

  testWidgets('a failed read of the pets is reported without its message, and the event\'s own '
      'pet stays offered', (tester) async {
    final rex = await addPet(tester, 'Rex');
    final event = await log(tester, rex, ExistingType('vomiting'), DateTime(2026, 11, 10, 8));

    await openEventScreen(tester, event, rex, pets: UnreadablePets());

    final error = tester.takeException();
    expect(error, isA<StateError>());
    expect(error.toString(), isNot(contains('Mia')));
    expect(petChips(tester), {'Rex': true});
  });

  testWidgets('a failed read of the types is reported without its message, and the event\'s '
      'own type stays offered', (tester) async {
    final rex = await addPet(tester, 'Rex');
    final event = await log(tester, rex, ExistingType('vomiting'), DateTime(2026, 11, 10, 8));

    await openEventScreen(tester, event, rex, eventTypes: UnreadableTypes());

    final error = tester.takeException();
    expect(error, isA<StateError>());
    expect(error.toString(), isNot(contains('Limping')));
    expect(pickedTypeId(tester), 'vomiting');
    await tester.tap(typeField);
    await tester.pumpAndSettle();
    expect(find.text('Sneezing'), findsNothing);
  });

  testWidgets('a failed save is reported without the write\'s message, and "Save" works again', (
    tester,
  ) async {
    final rex = await addPet(tester, 'Rex');
    await log(tester, rex, ExistingType('vomiting'), DateTime(2026, 11, 10, 8));
    await openHistory(tester, rex, events: FailingUpdate(app.events));
    await openEvent(tester, 'Vomiting');
    await tester.enterText(find.widgetWithText(TextField, 'Note (optional)'), 'Private note');

    final errors = <Object>[];
    await runZonedGuarded(() async {
      await tester.ensureVisible(saveButton);
      await tester.tap(saveButton);
      await tester.pumpAndSettle();
    }, (error, _) => errors.add(error));
    await tester.pumpAndSettle();

    expect(errors, hasLength(1));
    expect(errors.single, isA<StateError>());
    expect(errors.single.toString(), isNot(contains('Private note')));
    expect(find.byType(EventScreen), findsOneWidget);
    expect(tester.widget<FilledButton>(saveButton).onPressed, isNotNull);
  });

  testWidgets('"Save" and "Delete" are disabled while saving, and the screen closes once saved', (
    tester,
  ) async {
    final rex = await addPet(tester, 'Rex');
    await log(tester, rex, ExistingType('vomiting'), DateTime(2026, 11, 10, 8));
    final events = SlowWrites(app.events);
    await openHistory(tester, rex, events: events);
    await openEvent(tester, 'Vomiting');

    await tester.ensureVisible(saveButton);
    await tester.tap(saveButton);
    await tester.pump();

    expect(tester.widget<FilledButton>(saveButton).onPressed, isNull);
    expect(tester.widget<TextButton>(deleteButton).onPressed, isNull);
    await tester.runAsync(() async {
      events.done.complete();
      await Future<void>.delayed(Duration.zero);
    });
    await tester.pumpAndSettle();
    expect(find.byType(EventScreen), findsNothing);
  });

  Future<void> tapDelete(WidgetTester tester) async {
    await tester.tap(find.descendant(of: find.byType(AppBar), matching: deleteButton));
    await tester.pumpAndSettle();
  }

  testWidgets('001-US4-S2: "Delete" asks "Delete this event?" first, and "Cancel" keeps it', (
    tester,
  ) async {
    final rex = await addPet(tester, 'Rex');
    await log(tester, rex, ExistingType('vomiting'), DateTime(2026, 11, 10, 8));
    await openHistory(tester, rex);
    await openEvent(tester, 'Vomiting');

    await tapDelete(tester);

    expect(find.text('Delete this event?'), findsOneWidget);
    await expectAccessible(tester);
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Delete this event?'), findsNothing);
    expect(find.byType(EventScreen), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(tileTexts(tester), ['Vomiting\nNov 10, 2026 8:00 AM']);
  });

  testWidgets('001-US4-S2 001-FR-011: "Delete" in the question deletes the event and returns to '
      'the history, where it is gone from the list and the summary counts', (tester) async {
    final rex = await addPet(tester, 'Rex');
    await log(tester, rex, ExistingType('vomiting'), DateTime(2026, 11, 10, 8));
    await log(tester, rex, ExistingType('vomiting'), DateTime(2026, 11, 12, 8));
    await openHistory(tester, rex);
    expect(inSummary('2 times'), findsOneWidget);

    await openEvent(tester, 'Nov 10');
    await tapDelete(tester);
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: deleteButton));
    await tester.pumpAndSettle();

    expect(find.byType(EventScreen), findsNothing);
    expect(tileTexts(tester), ['Vomiting\nNov 12, 2026 8:00 AM']);
    expect(inSummary('1 time'), findsOneWidget);
    expect(inSummary('2 times'), findsNothing);
  });

  testWidgets('a failed delete is reported, and the event screen stays open', (tester) async {
    final rex = await addPet(tester, 'Rex');
    await log(tester, rex, ExistingType('vomiting'), DateTime(2026, 11, 10, 8));
    await openHistory(tester, rex, events: FailingUpdate(app.events));
    await openEvent(tester, 'Vomiting');

    final errors = <Object>[];
    await runZonedGuarded(() async {
      await tapDelete(tester);
      await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: deleteButton));
      await tester.pumpAndSettle();
    }, (error, _) => errors.add(error));
    await tester.pumpAndSettle();

    expect(errors, hasLength(1));
    expect(errors.single, isA<StateError>());
    expect(find.byType(EventScreen), findsOneWidget);
    expect(tester.widget<TextButton>(deleteButton).onPressed, isNotNull);
  });

  testWidgets('"Delete" and "Save" are disabled while deleting, and the screen closes once '
      'deleted', (tester) async {
    final rex = await addPet(tester, 'Rex');
    await log(tester, rex, ExistingType('vomiting'), DateTime(2026, 11, 10, 8));
    final events = SlowWrites(app.events);
    await openHistory(tester, rex, events: events);
    await openEvent(tester, 'Vomiting');

    await tapDelete(tester);
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: deleteButton));
    await tester.pumpAndSettle();

    expect(tester.widget<TextButton>(deleteButton).onPressed, isNull);
    expect(tester.widget<FilledButton>(saveButton).onPressed, isNull);
    await tester.runAsync(() async {
      events.done.complete();
      await Future<void>.delayed(Duration.zero);
    });
    await tester.pumpAndSettle();
    expect(find.byType(EventScreen), findsNothing);
    expect(tileTexts(tester), isEmpty);
  });
}
