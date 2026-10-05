import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pet_health_tracker/core/firebase_providers.dart';
import 'package:pet_health_tracker/data/symptom_log_repository.dart';
import 'package:pet_health_tracker/features/symptoms/log_symptom_screen.dart';

import '../../helpers.dart';

class MockSymptomLogRepository extends Mock implements SymptomLogRepository {}

void main() {
  late MockSymptomLogRepository repository;

  setUpAll(() => registerFallbackValue(DateTime(2026)));

  setUp(() => repository = MockSymptomLogRepository());

  void stubAdd(Future<void> Function() answer) {
    when(
      () => repository.addOtherLog(
        householdId: any(named: 'householdId'),
        petId: any(named: 'petId'),
        createdBy: any(named: 'createdBy'),
        title: any(named: 'title'),
        occurredAt: any(named: 'occurredAt'),
        notes: any(named: 'notes'),
      ),
    ).thenAnswer((_) => answer());
  }

  /// Pumps a button that opens the log screen, so popping it can be observed.
  Future<void> openLogScreen(WidgetTester tester) async {
    await tester.pumpScoped(
      Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (context) => const LogSymptomScreen(
                  householdId: 'h1',
                  petId: 'p1',
                  petName: 'Boogie',
                  uid: 'u1',
                ),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
      overrides: [symptomLogRepositoryProvider.overrideWithValue(repository)],
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Finder field(String label) => find.widgetWithText(TextField, label);

  testWidgets('shows the pet name and defaults the time to now', (tester) async {
    await openLogScreen(tester);

    expect(find.text('Log for Boogie'), findsOneWidget);
    expect(find.text('Now'), findsOneWidget);
  });

  testWidgets('asks for a title before saving', (tester) async {
    await openLogScreen(tester);
    await tester.enterText(field('Title'), '   ');
    await tester.tap(find.text('Save'));
    await tester.pump();

    expect(find.text('Enter a title'), findsOneWidget);
    verifyNever(
      () => repository.addOtherLog(
        householdId: any(named: 'householdId'),
        petId: any(named: 'petId'),
        createdBy: any(named: 'createdBy'),
        title: any(named: 'title'),
        occurredAt: any(named: 'occurredAt'),
        notes: any(named: 'notes'),
      ),
    );
  });

  testWidgets('saves the trimmed title and notes as the signed-in user', (tester) async {
    stubAdd(() async {});
    final before = DateTime.now();

    await openLogScreen(tester);
    await tester.enterText(field('Title'), '  Ate a sock ');
    await tester.enterText(field('Notes (optional)'), ' Some fabric missing ');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final occurredAt =
        verify(
              () => repository.addOtherLog(
                householdId: 'h1',
                petId: 'p1',
                createdBy: 'u1',
                title: 'Ate a sock',
                occurredAt: captureAny(named: 'occurredAt'),
                notes: 'Some fabric missing',
              ),
            ).captured.single
            as DateTime;
    expect(occurredAt.isBefore(before), isFalse);
    expect(find.byType(LogSymptomScreen), findsNothing);
  });

  testWidgets('closes without waiting for the server, so it works offline', (tester) async {
    final pending = Completer<void>();
    stubAdd(() => pending.future);

    await openLogScreen(tester);
    await tester.enterText(field('Title'), 'Ate a sock');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.byType(LogSymptomScreen), findsNothing);
  });

  testWidgets('says so when the server rejects the log', (tester) async {
    stubAdd(() => Future.error('permission-denied'));

    await openLogScreen(tester);
    await tester.enterText(field('Title'), 'Ate a sock');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text("Couldn't save the log: permission-denied"), findsOneWidget);
  });

  testWidgets('lets the user pick an earlier date and time', (tester) async {
    stubAdd(() async {});
    final yesterday = DateTime.now().subtract(const Duration(days: 1));

    await openLogScreen(tester);
    await tester.tap(find.text('Now'));
    await tester.pumpAndSettle();
    // The date picker opens on today; pick yesterday's day of the month,
    // switching to the previous month first when today is the 1st.
    if (yesterday.month != DateTime.now().month) {
      await tester.tap(find.byTooltip('Previous month'));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('${yesterday.day}').last);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    // Then the time picker; keep its time.
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(find.text('Now'), findsNothing);

    await tester.enterText(field('Title'), 'Ate a sock');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final occurredAt =
        verify(
              () => repository.addOtherLog(
                householdId: 'h1',
                petId: 'p1',
                createdBy: 'u1',
                title: 'Ate a sock',
                occurredAt: captureAny(named: 'occurredAt'),
                notes: '',
              ),
            ).captured.single
            as DateTime;
    expect(
      (occurredAt.year, occurredAt.month, occurredAt.day),
      (yesterday.year, yesterday.month, yesterday.day),
    );
  });

  testWidgets('keeps the time when the date picker is cancelled', (tester) async {
    await openLogScreen(tester);
    await tester.tap(find.text('Now'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Now'), findsOneWidget);
  });
}
