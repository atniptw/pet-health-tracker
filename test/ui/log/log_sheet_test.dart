import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_health_tracker/data/repositories.dart';
import 'package:pet_health_tracker/domain/built_in_event_types.dart';
import 'package:pet_health_tracker/domain/event_type.dart';
import 'package:pet_health_tracker/domain/medical_event.dart';
import 'package:pet_health_tracker/domain/pet.dart';
import 'package:pet_health_tracker/ui/app_scope.dart';
import 'package:pet_health_tracker/ui/common/date_time_field.dart';
import 'package:pet_health_tracker/ui/log/log_sheet.dart';
import 'package:pet_health_tracker/ui/log/pet_choices.dart';

import '../../support/pickers.dart';
import '../../support/screen_checks.dart';
import '../../support/test_app.dart';

EventType builtIn(String name) => builtInEventTypes.firstWhere((type) => type.name == name);

Finder get saveButton => find.widgetWithText(FilledButton, 'Save');

Finder get noteField => find.widgetWithText(TextField, 'Note (optional)');

bool isEnabled(WidgetTester tester) => tester.widget<FilledButton>(saveButton).onPressed != null;

/// An [EventRepository] whose `log` waits for [pending] and then fails with
/// [failure], if set; anything else is unused by the sheet.
class SlowEvents implements EventRepository {
  final pending = Completer<void>();
  Object? failure;
  var logCalls = 0;

  @override
  Future<MedicalEvent> log({
    required String petId,
    required TypeChoice type,
    required DateTime occurredAt,
    Map<String, Object> details = const {},
    String? note,
  }) async {
    logCalls++;
    await pending.future;
    throw failure ?? StateError('No event');
  }

  @override
  Never noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  late TestApp app;
  late Pet rex;
  late Pet mia;
  var now = DateTime(2026, 11, 14, 12);

  setUp(() async {
    now = DateTime(2026, 11, 14, 12);
    app = await openTestApp(now: now);
  });

  Future<void> addPets(WidgetTester tester) async {
    await tester.runAsync(() async {
      rex = await app.pets.add(name: 'Rex', species: Species.dog);
      mia = await app.pets.add(name: 'Mia', species: Species.cat);
    });
  }

  Future<List<MedicalEvent>> eventsFor(WidgetTester tester, Pet pet) async =>
      (await tester.runAsync(() => app.events.watchForPet(pet.id).first))!;

  /// Shows a button that opens [sheet] as a bottom sheet, taps it, and
  /// returns the list the sheet's result is added to once it closes.
  Future<List<MedicalEvent?>> openSheet(
    WidgetTester tester,
    LogSheet Function() sheet, {
    EventRepository? events,
  }) async {
    final results = <MedicalEvent?>[];
    await tester.pumpWidget(
      AppScope(
        pets: app.pets,
        eventTypes: app.eventTypes,
        events: events ?? app.events,
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async => results.add(
                  await showModalBottomSheet<MedicalEvent>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => sheet(),
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    return results;
  }

  Future<void> tapSave(WidgetTester tester) async {
    await tester.ensureVisible(saveButton);
    await tester.tap(saveButton);
    await tester.pumpAndSettle();
  }

  LogSheet vomitingFor(String? pickedPetId) => LogSheet.forType(
    builtIn('Vomiting'),
    pets: [rex, mia],
    pickedPetId: pickedPetId,
    clock: () => now,
  );

  testWidgets(
    '001-US1-S6: the type and pet shown, Save straight away logs it now with nothing else',
    (tester) async {
      await addPets(tester);
      final results = await openSheet(tester, () => vomitingFor(rex.id));

      expect(find.text('Vomiting'), findsOneWidget);
      expect(find.text('Rex'), findsOneWidget);
      expect(find.byType(PetChoices), findsNothing);
      expect(find.text('Now'), findsOneWidget);
      expect(find.text('What came up'), findsOneWidget);
      expect(noteField, findsOneWidget);
      expect(isEnabled(tester), isTrue);

      await tapSave(tester);

      final events = await eventsFor(tester, rex);
      expect(events, hasLength(1));
      final event = events.single;
      expect(event.typeId, 'vomiting');
      expect(event.occurredAt, now.toUtc());
      expect(event.details, isEmpty);
      expect(event.note, isNull);
      expect(results, [event]);
      expect(find.byType(LogSheet), findsNothing);
    },
  );

  testWidgets(
    '001-US1-S3: several pets, none picked → the pet choices, and Save disabled until one is chosen',
    (tester) async {
      await addPets(tester);
      final results = await openSheet(tester, () => vomitingFor(null));

      expect(find.byType(PetChoices), findsOneWidget);
      expect(find.text('Who is this for?'), findsOneWidget);
      expect(isEnabled(tester), isFalse);
      await tester.tap(saveButton);
      await tester.pumpAndSettle();
      expect(find.byType(LogSheet), findsOneWidget);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Mia'));
      await tester.pump();
      expect(isEnabled(tester), isTrue);
      await tapSave(tester);

      expect(await eventsFor(tester, rex), isEmpty);
      final events = await eventsFor(tester, mia);
      expect(events, hasLength(1));
      expect(results, [events.single]);
    },
  );

  testWidgets('001-FR-005: Save is enabled as soon as a pet is picked, with nothing else entered', (
    tester,
  ) async {
    await addPets(tester);
    await openSheet(tester, () => vomitingFor(null));

    expect(isEnabled(tester), isFalse);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Rex'));
    await tester.pump();

    expect(isEnabled(tester), isTrue);
    expect(find.text('Now'), findsOneWidget);
    expect(tester.widget<TextField>(noteField).controller!.text, isEmpty);
  });

  testWidgets('001-US1-S3: a picked id that is not among the active pets → none picked', (
    tester,
  ) async {
    await addPets(tester);
    await openSheet(tester, () => vomitingFor('archived-pet'));

    expect(find.text('Who is this for?'), findsOneWidget);
    expect(isEnabled(tester), isFalse);
  });

  testWidgets('001-US1-S3: once chosen in the sheet, the pet choices stay and can change (D-010)', (
    tester,
  ) async {
    await addPets(tester);
    await openSheet(tester, () => vomitingFor(null));

    await tester.tap(find.widgetWithText(ChoiceChip, 'Rex'));
    await tester.pump();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Mia'));
    await tester.pump();

    expect(find.byType(PetChoices), findsOneWidget);
    await tapSave(tester);
    expect(await eventsFor(tester, mia), hasLength(1));
    expect(await eventsFor(tester, rex), isEmpty);
  });

  testWidgets('001-FR-006: the time, details and note entered are saved with the event', (
    tester,
  ) async {
    await addPets(tester);
    await openSheet(
      tester,
      () =>
          LogSheet.forType(builtIn('Seizure'), pets: [rex], pickedPetId: rex.id, clock: () => now),
    );

    await openPickers(tester);
    await pickDay(tester, 13);
    await pickTime(tester, 9, 30, 'PM');
    await tester.tap(find.widgetWithText(ChoiceChip, 'Grand mal'));
    await tester.enterText(find.widgetWithText(TextField, 'Minutes'), '2');
    await tester.enterText(noteField, '  After dinner ');
    await tester.pump();
    await tapSave(tester);

    final event = (await eventsFor(tester, rex)).single;
    expect(event.typeId, 'seizure');
    expect(event.occurredAt, DateTime(2026, 11, 13, 21, 30).toUtc());
    expect(event.details, {'kind': 'grand_mal', 'duration': 120});
    expect(event.note, 'After dinner');
  });

  testWidgets('001-FR-005: a name typed in the caregiver\'s own words is logged as a new type', (
    tester,
  ) async {
    await addPets(tester);
    final results = await openSheet(
      tester,
      () => LogSheet.forNewName('Ear shaking', pets: [rex], pickedPetId: rex.id, clock: () => now),
    );

    expect(find.text('Ear shaking'), findsOneWidget);
    expect(find.byType(ChoiceChip), findsNothing);
    await tapSave(tester);

    final custom = (await tester.runAsync(() => app.eventTypes.watchCustom().first))!;
    expect(custom.map((type) => type.name), ['Ear shaking']);
    final event = (await eventsFor(tester, rex)).single;
    expect(event.typeId, custom.single.id);
    expect(results, [event]);
  });

  testWidgets(
    '001-EC-01: a time after now when saving → "That time is in the future", the sheet stays open',
    (tester) async {
      await addPets(tester);
      await openSheet(tester, () => vomitingFor(rex.id));
      await openPickers(tester);
      await pickDay(tester, 14);
      await pickTime(tester, 11, 30, 'AM');
      expect(find.text('That time is in the future'), findsNothing);

      now = DateTime(2026, 11, 14, 11);
      await tapSave(tester);

      expect(find.text('That time is in the future'), findsOneWidget);
      expect(find.byType(LogSheet), findsOneWidget);
      expect(isEnabled(tester), isTrue);
      expect(await eventsFor(tester, rex), isEmpty);

      await openPickers(tester);
      await pickDay(tester, 14);
      await pickTime(tester, 10, 0, 'AM');
      expect(find.text('That time is in the future'), findsNothing);
      await tapSave(tester);

      final event = (await eventsFor(tester, rex)).single;
      expect(event.occurredAt, DateTime(2026, 11, 14, 10).toUtc());
    },
  );

  testWidgets('001-EC-01: the message shows under "When" (D-011)', (tester) async {
    await addPets(tester);
    await openSheet(tester, () => vomitingFor(rex.id));
    await openPickers(tester);
    await pickDay(tester, 14);
    await pickTime(tester, 11, 30, 'AM');

    now = DateTime(2026, 11, 14, 11);
    await tapSave(tester);

    expect(
      find.descendant(
        of: find.byType(DateTimeField),
        matching: find.text('That time is in the future'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('001-FR-005: Save is disabled while saving, so one tap logs one event', (
    tester,
  ) async {
    await addPets(tester);
    final events = SlowEvents();
    await openSheet(tester, () => vomitingFor(rex.id), events: events);

    await tester.tap(saveButton);
    await tester.pump();

    expect(isEnabled(tester), isFalse);
    await tester.tap(saveButton, warnIfMissed: false);
    await tester.pump();
    expect(events.logCalls, 1);
  });

  testWidgets(
    '001-FR-005: when logging fails, the sheet stays open with Save enabled and the error reported leaves out the note',
    (tester) async {
      await addPets(tester);
      final events = SlowEvents()
        ..failure = Exception('INSERT INTO events failed, args [Ate a sock]');
      await openSheet(tester, () => vomitingFor(rex.id), events: events);
      await tester.enterText(noteField, 'Ate a sock');
      await tester.pump();

      final errors = <Object>[];
      await runZonedGuarded(() async {
        await tester.tap(saveButton);
        events.pending.complete();
        await tester.pump();
      }, (error, _) => errors.add(error));
      await tester.pump();

      expect(errors, hasLength(1));
      expect(errors.single.toString(), isNot(contains('Ate a sock')));
      expect(find.byType(LogSheet), findsOneWidget);
      expect(isEnabled(tester), isTrue);
    },
  );

  testWidgets('001-FR-006: the note takes up to 1000 characters', (tester) async {
    await addPets(tester);
    await openSheet(tester, () => vomitingFor(rex.id));

    await tester.enterText(noteField, 'a' * 1001);
    await tester.pump();

    expect(tester.widget<TextField>(noteField).controller!.text, 'a' * 1000);
  });

  testWidgets('001-US1-S3: the sheet with the pet choices and questions is accessible', (
    tester,
  ) async {
    await addPets(tester);
    await openSheet(
      tester,
      () => LogSheet.forType(
        builtIn('Seizure'),
        pets: [rex, mia],
        pickedPetId: null,
        clock: () => now,
      ),
    );

    await expectAccessible(tester);
  });
}
