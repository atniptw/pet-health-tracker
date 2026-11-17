import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_health_tracker/data/repositories.dart';
import 'package:pet_health_tracker/domain/event_type.dart';
import 'package:pet_health_tracker/domain/medical_event.dart';
import 'package:pet_health_tracker/domain/pet.dart';
import 'package:pet_health_tracker/ui/app_scope.dart';
import 'package:pet_health_tracker/ui/log/log_screen.dart';
import 'package:pet_health_tracker/ui/log/type_grid.dart';
import 'package:pet_health_tracker/ui/types/my_event_types_screen.dart';

import '../../support/robot.dart';
import '../../support/screen_checks.dart';
import '../../support/test_app.dart';

Finder typeButton(String name) =>
    find.descendant(of: find.byType(TypeGrid), matching: find.widgetWithText(FilledButton, name));

Finder removeButton(String name) => find.descendant(
  of: find.widgetWithText(ListTile, name),
  matching: find.widgetWithText(TextButton, 'Remove'),
);

EventType custom(String id, String name) => EventType(id: id, name: name, builtIn: false);

/// An [EventTypeRepository] whose custom types are the lists and errors the
/// test sends, and whose `remove` waits for [pending] and then fails with
/// [failure] if set. Anything else is unused by the screen.
class ControlledTypes implements EventTypeRepository {
  final _custom = StreamController<List<EventType>>.broadcast();
  final removed = <String>[];
  var pending = Completer<void>();
  Object? failure;

  void send(List<EventType> types) => _custom.add(types);

  void fail(Object error) => _custom.addError(error, StackTrace.current);

  @override
  Stream<List<EventType>> watchCustom() => _custom.stream;

  @override
  Future<void> remove(String customId) async {
    removed.add(customId);
    await pending.future;
    if (failure case final failure?) throw failure;
  }

  @override
  Never noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  late TestApp app;
  final now = DateTime(2026, 11, 14, 12);

  setUp(() async => app = await openTestApp(now: now));

  Future<Pet> addPet(WidgetTester tester, String name) async =>
      (await tester.runAsync(() => app.pets.add(name: name, species: Species.dog)))!;

  Future<MedicalEvent> logTyped(WidgetTester tester, Pet pet, String name) async => (await tester
      .runAsync(() => app.events.log(petId: pet.id, type: NewTypeName(name), occurredAt: now)))!;

  Future<List<MedicalEvent>> eventsFor(WidgetTester tester, Pet pet) async =>
      (await tester.runAsync(() => app.events.watchForPet(pet.id).first))!;

  Widget screenIn({EventTypeRepository? eventTypes, Key? key}) => AppScope(
    pets: app.pets,
    eventTypes: eventTypes ?? app.eventTypes,
    events: app.events,
    child: MaterialApp(home: MyEventTypesScreen(key: key)),
  );

  Future<void> openScreen(WidgetTester tester, {EventTypeRepository? eventTypes}) async {
    await tester.pumpWidget(screenIn(eventTypes: eventTypes));
    await tester.pumpAndSettle();
  }

  Future<void> openLog(WidgetTester tester) async {
    await tester.pumpWidget(app.wrap(LogScreen(clock: () => now)));
    await tester.pumpAndSettle();
  }

  bool removeEnabled(WidgetTester tester, String name) =>
      tester.widget<TextButton>(removeButton(name)).onPressed != null;

  testWidgets('001-FR-004: lists the custom types still offered by name, each with "Remove"', (
    tester,
  ) async {
    final rex = await addPet(tester, 'Rex');
    await logTyped(tester, rex, 'Head tilt');
    await logTyped(tester, rex, 'Ear shaking');
    final gone = await logTyped(tester, rex, 'Hiccups');
    await tester.runAsync(() => app.eventTypes.remove(gone.typeId));

    await openScreen(tester);

    expect(find.text('My event types'), findsOneWidget);
    final names = tester
        .widgetList<ListTile>(find.byType(ListTile))
        .map((tile) => (tile.title as Text?)?.data);
    expect(names, ['Ear shaking', 'Head tilt']);
    expect(removeButton('Ear shaking'), findsOneWidget);
    expect(removeButton('Head tilt'), findsOneWidget);
    expect(find.text('Vomiting'), findsNothing);
  });

  testWidgets('001-FR-004: with no custom types, says "Types you type in yourself appear here"', (
    tester,
  ) async {
    await openScreen(tester);

    expect(find.text('Types you type in yourself appear here'), findsOneWidget);
    expect(find.byType(ListTile), findsNothing);
  });

  testWidgets('001-US1-S9 001-FR-004: a type removed from My event types, with nothing more '
      'asked, leaves the grid, and its past events keep it', (tester) async {
    final rex = await addPet(tester, 'Rex');
    final first = await logTyped(tester, rex, 'Ear shaking');
    await openLog(tester);
    expect(typeButton('Ear shaking'), findsOneWidget);

    await tester.tap(find.byTooltip('Menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('My event types'));
    await tester.pumpAndSettle();
    await tester.tap(removeButton('Ear shaking'));
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsNothing);
    expect(find.widgetWithText(ListTile, 'Ear shaking'), findsNothing);
    expect(find.text('Types you type in yourself appear here'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(typeButton('Ear shaking'), findsNothing);
    final events = await eventsFor(tester, rex);
    expect(events.map((event) => event.typeId), [first.typeId]);
    final kept = (await tester.runAsync(() => app.eventTypes.byId(first.typeId)))!;
    expect(kept.name, 'Ear shaking');
  });

  testWidgets('001-EC-04 001-FR-004: removed through My event types and typed again → offered '
      'again, its events counted together under the same type', (tester) async {
    final rex = await addPet(tester, 'Rex');
    final first = await logTyped(tester, rex, 'Ear shaking');
    await openLog(tester);
    final robot = Robot(tester);

    await robot.removeEventType('Ear shaking');
    expect(typeButton('Ear shaking'), findsNothing);
    await robot.logSomethingElse('Ear shaking');

    expect(typeButton('Ear shaking'), findsOneWidget);
    expect((await eventsFor(tester, rex)).map((event) => event.typeId), [
      first.typeId,
      first.typeId,
    ]);
  });

  testWidgets('tapping "Remove" twice removes the type once', (tester) async {
    final types = ControlledTypes();
    await openScreen(tester, eventTypes: types);
    types.send([custom('c1', 'Ear shaking')]);
    await tester.pumpAndSettle();

    await tester.tap(removeButton('Ear shaking'));
    await tester.pump();
    expect(removeEnabled(tester, 'Ear shaking'), isFalse);
    await tester.tap(removeButton('Ear shaking'), warnIfMissed: false);
    await tester.pump();

    expect(types.removed, ['c1']);
  });

  testWidgets('when removing fails, "Remove" works again and the error reported leaves out '
      'the type\'s name', (tester) async {
    final types = ControlledTypes()
      ..failure = Exception('UPDATE event_types failed for Ear shaking');
    await openScreen(tester, eventTypes: types);
    types.send([custom('c1', 'Ear shaking')]);
    await tester.pumpAndSettle();

    final errors = <Object>[];
    await runZonedGuarded(() async {
      await tester.tap(removeButton('Ear shaking'));
      types.pending.complete();
      await tester.pump();
    }, (error, _) => errors.add(error));
    await tester.pump();

    expect(errors, hasLength(1));
    expect(errors.single.toString(), isNot(contains('Ear shaking')));
    expect(removeEnabled(tester, 'Ear shaking'), isTrue);
  });

  testWidgets('a failed read before any list says the types couldn\'t be loaded (D-018) and '
      'reports the error without a type\'s name', (tester) async {
    final types = ControlledTypes();
    await openScreen(tester, eventTypes: types);

    types.fail(Exception('SELECT FROM event_types failed for Ear shaking'));
    await tester.pumpAndSettle();

    final error = tester.takeException();
    expect(error, isNotNull);
    expect(error.toString(), isNot(contains('Ear shaking')));
    expect(find.text(MyEventTypesScreen.loadFailed), findsOneWidget);
    expect(find.text('Types you type in yourself appear here'), findsNothing);
    types.send([custom('c1', 'Ear shaking')]);
    await tester.pumpAndSettle();
    expect(find.text(MyEventTypesScreen.loadFailed), findsNothing);
    expect(removeButton('Ear shaking'), findsOneWidget);
  });

  testWidgets('a failed read after a list keeps the list shown (D-018)', (tester) async {
    final types = ControlledTypes();
    await openScreen(tester, eventTypes: types);
    types.send([custom('c1', 'Ear shaking')]);
    await tester.pumpAndSettle();

    types.fail(Exception('SELECT FROM event_types failed for Ear shaking'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNotNull);
    expect(removeButton('Ear shaking'), findsOneWidget);
    expect(find.text(MyEventTypesScreen.loadFailed), findsNothing);
  });

  testWidgets('other repositories → their custom types', (tester) async {
    final rex = await addPet(tester, 'Rex');
    await logTyped(tester, rex, 'Head tilt');
    final other = ControlledTypes();
    final key = GlobalKey();
    await tester.pumpWidget(screenIn(key: key));
    await tester.pumpAndSettle();
    expect(removeButton('Head tilt'), findsOneWidget);

    await tester.pumpWidget(screenIn(key: key, eventTypes: other));
    other.send([custom('c1', 'Ear shaking')]);
    await tester.pumpAndSettle();

    expect(removeButton('Head tilt'), findsNothing);
    expect(removeButton('Ear shaking'), findsOneWidget);
  });

  testWidgets('My event types is accessible with types and with none', (tester) async {
    await openScreen(tester);
    await expectAccessible(tester);

    final rex = await addPet(tester, 'Rex');
    await logTyped(tester, rex, 'Ear shaking');
    await tester.pumpAndSettle();
    expect(removeButton('Ear shaking'), findsOneWidget);
    await expectAccessible(tester);
  });
}
