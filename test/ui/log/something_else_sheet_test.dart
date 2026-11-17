import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_health_tracker/data/repositories.dart';
import 'package:pet_health_tracker/domain/medical_event.dart';
import 'package:pet_health_tracker/domain/pet.dart';
import 'package:pet_health_tracker/ui/app_scope.dart';
import 'package:pet_health_tracker/ui/log/log_screen.dart';
import 'package:pet_health_tracker/ui/log/log_sheet.dart';
import 'package:pet_health_tracker/ui/log/something_else_sheet.dart';
import 'package:pet_health_tracker/ui/log/type_grid.dart';

import '../../support/robot.dart';
import '../../support/screen_checks.dart';
import '../../support/test_app.dart';

Finder typeButton(String name) =>
    find.descendant(of: find.byType(TypeGrid), matching: find.widgetWithText(FilledButton, name));

Finder get somethingElse => find.widgetWithText(OutlinedButton, 'Something else');

Finder get whatHappened => find.widgetWithText(TextField, 'What happened?');

Finder get continueButton => find.widgetWithText(FilledButton, 'Continue');

Finder inLogSheet(Finder finder) => find.descendant(of: find.byType(LogSheet), matching: finder);

void main() {
  late TestApp app;
  final now = DateTime(2026, 11, 14, 12);

  setUp(() async => app = await openTestApp(now: now));

  Future<Pet> addPet(WidgetTester tester, String name) async =>
      (await tester.runAsync(() => app.pets.add(name: name, species: Species.dog)))!;

  Future<List<MedicalEvent>> eventsFor(WidgetTester tester, Pet pet) async =>
      (await tester.runAsync(() => app.events.watchForPet(pet.id).first))!;

  Future<void> openLog(WidgetTester tester) async {
    await tester.pumpWidget(app.wrap(LogScreen(clock: () => now)));
    await tester.pumpAndSettle();
  }

  /// Taps "Something else" and types [name] under "What happened?".
  Future<void> typeSomethingElse(WidgetTester tester, String name) async {
    await tester.ensureVisible(somethingElse);
    await tester.pumpAndSettle();
    await tester.tap(somethingElse);
    await tester.pumpAndSettle();
    await tester.enterText(whatHappened, name);
    await tester.pump();
  }

  bool continueEnabled(WidgetTester tester) =>
      tester.widget<FilledButton>(continueButton).onPressed != null;

  testWidgets('001-US1-S5 001-FR-004: "Ear shaking" saved and then offered in the grid', (
    tester,
  ) async {
    final rex = await addPet(tester, 'Rex');
    await openLog(tester);
    expect(typeButton('Ear shaking'), findsNothing);

    await Robot(tester).logSomethingElse('Ear shaking');

    expect(find.text('Saved: Ear shaking for Rex'), findsOneWidget);
    expect(typeButton('Ear shaking'), findsOneWidget);
    final custom = (await tester.runAsync(() => app.eventTypes.watchCustom().first))!;
    expect(custom.map((type) => type.name), ['Ear shaking']);
    expect((await eventsFor(tester, rex)).map((event) => event.typeId), [custom.single.id]);
  });

  testWidgets('001-EC-07: "ear SHAKING" saved as the existing "Ear shaking", '
      'with no second type created', (tester) async {
    final rex = await addPet(tester, 'Rex');
    final first = (await tester.runAsync(
      () => app.events.log(petId: rex.id, type: NewTypeName('Ear shaking'), occurredAt: now),
    ))!;
    await openLog(tester);

    await typeSomethingElse(tester, 'ear SHAKING');
    await tester.tap(continueButton);
    await tester.pumpAndSettle();
    expect(inLogSheet(find.text('Ear shaking')), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.text('Saved: Ear shaking for Rex'), findsOneWidget);
    final custom = (await tester.runAsync(() => app.eventTypes.watchCustom().first))!;
    expect(custom.map((type) => type.name), ['Ear shaking']);
    expect((await eventsFor(tester, rex)).map((event) => event.typeId), [
      first.typeId,
      first.typeId,
    ]);
  });

  testWidgets('001-EC-07: a built-in type typed with other capitalization and spacing '
      'opens its log sheet, with its detail questions', (tester) async {
    await addPet(tester, 'Rex');
    await openLog(tester);

    await typeSomethingElse(tester, '  SEIZURE ');
    await tester.tap(continueButton);
    await tester.pumpAndSettle();

    expect(inLogSheet(find.text('Seizure')), findsOneWidget);
    expect(find.text('How long it lasted'), findsOneWidget);
  });

  testWidgets('001-FR-004: a new name is saved with its spaces trimmed and collapsed '
      'and its capitalization kept', (tester) async {
    await addPet(tester, 'Rex');
    await openLog(tester);

    await Robot(tester).logSomethingElse('  Ear   SHAKING ');

    expect(find.text('Saved: Ear SHAKING for Rex'), findsOneWidget);
    expect(typeButton('Ear SHAKING'), findsOneWidget);
  });

  testWidgets('001-FR-004: a removed type typed again is offered again', (tester) async {
    final rex = await addPet(tester, 'Rex');
    final first = (await tester.runAsync(
      () => app.events.log(petId: rex.id, type: NewTypeName('Ear shaking'), occurredAt: now),
    ))!;
    await tester.runAsync(() => app.eventTypes.remove(first.typeId));
    await openLog(tester);
    expect(typeButton('Ear shaking'), findsNothing);

    await Robot(tester).logSomethingElse('ear shaking');

    expect(find.text('Saved: Ear shaking for Rex'), findsOneWidget);
    expect(typeButton('Ear shaking'), findsOneWidget);
    expect((await eventsFor(tester, rex)).map((event) => event.typeId), [
      first.typeId,
      first.typeId,
    ]);
  });

  testWidgets('"Something else" is the last button in the type grid', (tester) async {
    await addPet(tester, 'Rex');
    await openLog(tester);

    final buttons = find.descendant(
      of: find.byType(TypeGrid),
      matching: find.byWidgetPredicate((widget) => widget is ButtonStyleButton),
    );
    final last = tester.widgetList<ButtonStyleButton>(buttons).last;
    expect(last, tester.widget(somethingElse));
  });

  testWidgets('"Something else" asks "What happened?" before the log sheet', (tester) async {
    await addPet(tester, 'Rex');
    await openLog(tester);

    await tester.ensureVisible(somethingElse);
    await tester.tap(somethingElse);
    await tester.pumpAndSettle();

    expect(find.byType(SomethingElseSheet), findsOneWidget);
    expect(whatHappened, findsOneWidget);
    expect(find.byType(LogSheet), findsNothing);
  });

  testWidgets('"Continue" is disabled while "What happened?" is empty or only spaces (D-014)', (
    tester,
  ) async {
    await addPet(tester, 'Rex');
    await openLog(tester);

    await typeSomethingElse(tester, '');
    expect(continueEnabled(tester), isFalse);
    await tester.enterText(whatHappened, '   ');
    await tester.pump();
    expect(continueEnabled(tester), isFalse);
    await tester.enterText(whatHappened, 'Ear shaking');
    await tester.pump();
    expect(continueEnabled(tester), isTrue);
  });

  testWidgets('"What happened?" takes up to 40 characters (D-014)', (tester) async {
    await addPet(tester, 'Rex');
    await openLog(tester);

    await typeSomethingElse(tester, 'a' * 45);

    expect(tester.widget<TextField>(whatHappened).controller!.text, 'a' * 40);
  });

  testWidgets('the keyboard\'s done key continues like "Continue"', (tester) async {
    await addPet(tester, 'Rex');
    await openLog(tester);

    await typeSomethingElse(tester, 'Ear shaking');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(inLogSheet(find.text('Ear shaking')), findsOneWidget);
  });

  testWidgets('the keyboard\'s done key on an empty name does nothing', (tester) async {
    await addPet(tester, 'Rex');
    await openLog(tester);

    await typeSomethingElse(tester, '  ');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.byType(SomethingElseSheet), findsOneWidget);
    expect(find.byType(LogSheet), findsNothing);
  });

  testWidgets('closing "What happened?" without continuing opens no log sheet', (tester) async {
    await addPet(tester, 'Rex');
    await openLog(tester);

    await typeSomethingElse(tester, 'Ear shaking');
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(find.byType(SomethingElseSheet), findsNothing);
    expect(find.byType(LogSheet), findsNothing);
  });

  testWidgets('001-FR-007: the pet picked on the log screen is the one the sheet logs for, '
      'and stays picked after saving', (tester) async {
    await addPet(tester, 'Rex');
    final mia = await addPet(tester, 'Mia');
    await openLog(tester);

    await Robot(tester).logSomethingElse('Ear shaking', pet: 'Mia');

    expect(find.text('Saved: Ear shaking for Mia'), findsOneWidget);
    expect(await eventsFor(tester, mia), hasLength(1));
    expect(tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Mia')).selected, isTrue);
  });

  testWidgets('repositories replaced while "What happened?" is open → no log sheet opens', (
    tester,
  ) async {
    final rex = await addPet(tester, 'Rex');
    final other = (await tester.runAsync(() => openTestApp(now: now)))!;
    final bo = (await tester.runAsync(() => other.pets.add(name: 'Bo', species: Species.cat)))!;
    final key = GlobalKey();
    Widget screenIn(TestApp repos) => AppScope(
      pets: repos.pets,
      eventTypes: repos.eventTypes,
      events: repos.events,
      child: MaterialApp(
        home: LogScreen(key: key, clock: () => now),
      ),
    );
    await tester.pumpWidget(screenIn(app));
    await tester.pumpAndSettle();
    await typeSomethingElse(tester, 'Ear shaking');

    await tester.pumpWidget(screenIn(other));
    await tester.pumpAndSettle();
    await tester.tap(continueButton);
    await tester.pumpAndSettle();

    expect(find.byType(LogSheet), findsNothing);
    expect(await eventsFor(tester, rex), isEmpty);
    expect((await tester.runAsync(() => other.events.watchForPet(bo.id).first))!, isEmpty);
  });

  testWidgets('"What happened?" is accessible', (tester) async {
    await addPet(tester, 'Rex');
    await openLog(tester);

    await typeSomethingElse(tester, 'Ear shaking');
    await tester.pumpAndSettle();

    await expectAccessible(tester);
  });
}
