import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pet_health_tracker/core/firebase_providers.dart';
import 'package:pet_health_tracker/data/symptom_log.dart';
import 'package:pet_health_tracker/data/symptom_log_repository.dart';
import 'package:pet_health_tracker/features/symptoms/edit_log_screen.dart';

import '../../helpers.dart';

class MockSymptomLogRepository extends Mock implements SymptomLogRepository {}

void main() {
  late MockSymptomLogRepository repository;

  final sock = SymptomLog(
    id: 'l1',
    symptom: SymptomLog.otherSymptom,
    title: 'Ate a sock',
    createdBy: 'u2',
    occurredAt: DateTime(2026, 10, 4, 14, 30),
    notes: 'Some fabric missing',
  );

  setUpAll(() => registerFallbackValue(DateTime(2026)));

  setUp(() => repository = MockSymptomLogRepository());

  void stubUpdate(Future<void> Function() answer) {
    when(
      () => repository.updateOtherLog(
        householdId: any(named: 'householdId'),
        petId: any(named: 'petId'),
        logId: any(named: 'logId'),
        title: any(named: 'title'),
        occurredAt: any(named: 'occurredAt'),
        notes: any(named: 'notes'),
      ),
    ).thenAnswer((_) => answer());
  }

  /// Pumps a button that opens the screen, so popping it can be observed.
  Future<void> openEditScreen(WidgetTester tester) async {
    await tester.pumpScoped(
      Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (context) => EditLogScreen(householdId: 'h1', petId: 'p1', log: sock),
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

  testWidgets('fills in the log', (tester) async {
    await openEditScreen(tester);

    expect(find.text('Edit log'), findsOneWidget);
    expect(find.text('Ate a sock'), findsOneWidget);
    expect(find.text('Some fabric missing'), findsOneWidget);
    expect(find.text('Sunday, October 4, 2026 · 2:30 PM'), findsOneWidget);
  });

  testWidgets('asks for a title before saving', (tester) async {
    await openEditScreen(tester);
    await tester.enterText(field('Title'), '   ');
    await tester.tap(find.text('Save'));
    await tester.pump();

    expect(find.text('Enter a title'), findsOneWidget);
    verifyNever(
      () => repository.updateOtherLog(
        householdId: any(named: 'householdId'),
        petId: any(named: 'petId'),
        logId: any(named: 'logId'),
        title: any(named: 'title'),
        occurredAt: any(named: 'occurredAt'),
        notes: any(named: 'notes'),
      ),
    );
  });

  testWidgets('saves the trimmed changes, keeping the time', (tester) async {
    stubUpdate(() async {});

    await openEditScreen(tester);
    await tester.enterText(field('Title'), ' Ate two socks ');
    await tester.enterText(field('Notes (optional)'), '');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    verify(
      () => repository.updateOtherLog(
        householdId: 'h1',
        petId: 'p1',
        logId: 'l1',
        title: 'Ate two socks',
        occurredAt: DateTime(2026, 10, 4, 14, 30),
        notes: '',
      ),
    ).called(1);
    expect(find.byType(EditLogScreen), findsNothing);
  });

  testWidgets('closes without waiting for the server', (tester) async {
    final pending = Completer<void>();
    stubUpdate(() => pending.future);

    await openEditScreen(tester);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.byType(EditLogScreen), findsNothing);
  });

  testWidgets('says so when the server rejects the change', (tester) async {
    stubUpdate(() => Future.error('permission-denied'));

    await openEditScreen(tester);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text("Couldn't save the log: permission-denied"), findsOneWidget);
  });

  testWidgets('lets the user pick another date, keeping the time of day', (tester) async {
    stubUpdate(() async {});

    await openEditScreen(tester);
    await tester.tap(find.text('Sunday, October 4, 2026 · 2:30 PM'));
    await tester.pumpAndSettle();
    // The date picker opens on the log's date.
    await tester.tap(find.text('3'));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    // Then the time picker; keep its time.
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(find.text('Saturday, October 3, 2026 · 2:30 PM'), findsOneWidget);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    verify(
      () => repository.updateOtherLog(
        householdId: 'h1',
        petId: 'p1',
        logId: 'l1',
        title: 'Ate a sock',
        occurredAt: DateTime(2026, 10, 3, 14, 30),
        notes: 'Some fabric missing',
      ),
    ).called(1);
  });

  testWidgets('keeps the time when the date picker is cancelled', (tester) async {
    await openEditScreen(tester);
    await tester.tap(find.text('Sunday, October 4, 2026 · 2:30 PM'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Sunday, October 4, 2026 · 2:30 PM'), findsOneWidget);
  });

  testWidgets('keeps the time when the time picker is cancelled', (tester) async {
    await openEditScreen(tester);
    await tester.tap(find.text('Sunday, October 4, 2026 · 2:30 PM'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('3'));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Sunday, October 4, 2026 · 2:30 PM'), findsOneWidget);
  });
}
