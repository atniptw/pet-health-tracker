import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pet_health_tracker/core/firebase_providers.dart';
import 'package:pet_health_tracker/data/pet.dart';
import 'package:pet_health_tracker/data/symptom_log.dart';
import 'package:pet_health_tracker/data/symptom_log_repository.dart';
import 'package:pet_health_tracker/features/symptoms/log_symptom_screen.dart';
import 'package:pet_health_tracker/features/symptoms/pet_logs_screen.dart';

import '../../helpers.dart';

class MockSymptomLogRepository extends Mock implements SymptomLogRepository {}

void main() {
  const boogie = Pet(id: 'p1', name: 'Boogie', species: Species.dog);

  late SymptomLogRepository logs;

  setUp(() => logs = SymptomLogRepository(FakeFirebaseFirestore()));

  Future<void> pumpLogs(
    WidgetTester tester, {
    SymptomLogRepository? repository,
    bool isAdmin = false,
  }) {
    return tester.pumpScoped(
      PetLogsScreen(householdId: 'h1', pet: boogie, uid: 'u1', isAdmin: isAdmin),
      overrides: [symptomLogRepositoryProvider.overrideWithValue(repository ?? logs)],
    );
  }

  testWidgets('shows the pet name', (tester) async {
    await pumpLogs(tester);

    expect(find.text('Boogie'), findsOneWidget);
  });

  testWidgets('says so when nothing has been logged', (tester) async {
    await pumpLogs(tester);
    await tester.pumpAndSettle();

    expect(find.text('Nothing logged yet'), findsOneWidget);
  });

  testWidgets('lists logs, most recent first, with time and notes', (tester) async {
    await logs.addOtherLog(
      householdId: 'h1',
      petId: 'p1',
      createdBy: 'u1',
      title: 'Ate a sock',
      occurredAt: DateTime(2026, 10, 4, 14, 30),
      notes: 'Some fabric missing',
    );
    await logs.addOtherLog(
      householdId: 'h1',
      petId: 'p1',
      createdBy: 'u1',
      title: 'Limping',
      occurredAt: DateTime(2026, 10, 5, 9, 5),
    );

    await pumpLogs(tester);
    await tester.pumpAndSettle();

    final limping = tester.getTopLeft(find.text('Limping'));
    final sock = tester.getTopLeft(find.text('Ate a sock'));
    expect(limping.dy, lessThan(sock.dy));
    expect(find.text('Monday, October 5, 2026 · 9:05 AM'), findsOneWidget);
    expect(find.text('Sunday, October 4, 2026 · 2:30 PM\nSome fabric missing'), findsOneWidget);
    expect(find.text('Nothing logged yet'), findsNothing);
  });

  testWidgets('falls back to the symptom key for a log with no title', (tester) async {
    final repository = MockSymptomLogRepository();
    when(() => repository.watchLogs(householdId: 'h1', petId: 'p1')).thenAnswer(
      (_) => Stream.value([
        SymptomLog(id: 'l1', symptom: 'vomit', createdBy: 'u2', occurredAt: DateTime(2026)),
      ]),
    );

    await pumpLogs(tester, repository: repository);
    await tester.pumpAndSettle();

    expect(find.text('vomit'), findsOneWidget);
  });

  testWidgets('shows a spinner while logs load', (tester) async {
    final repository = MockSymptomLogRepository();
    when(() => repository.watchLogs(householdId: 'h1', petId: 'p1'))
        .thenAnswer((_) => const Stream.empty());

    await pumpLogs(tester, repository: repository);

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('shows the error when logs fail to load and retries on tap', (tester) async {
    final repository = MockSymptomLogRepository();
    when(() => repository.watchLogs(householdId: 'h1', petId: 'p1'))
        .thenAnswer((_) => Stream.error('offline'));

    await pumpLogs(tester, repository: repository);
    await tester.pumpAndSettle();
    expect(find.text('offline'), findsOneWidget);

    when(() => repository.watchLogs(householdId: 'h1', petId: 'p1'))
        .thenAnswer((_) => Stream.value(const <SymptomLog>[]));
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.text('Nothing logged yet'), findsOneWidget);
  });

  testWidgets('opens the log screen for this pet', (tester) async {
    await pumpLogs(tester);
    await tester.tap(find.text('Log symptom'));
    await tester.pumpAndSettle();

    final screen = tester.widget<LogSymptomScreen>(find.byType(LogSymptomScreen));
    expect(
      (screen.householdId, screen.petId, screen.petName, screen.uid),
      ('h1', 'p1', 'Boogie', 'u1'),
    );
    expect(screen.log, isNull);
  });

  group('editing', () {
    Future<void> addLog(String title, {required String createdBy}) => logs.addOtherLog(
      householdId: 'h1',
      petId: 'p1',
      createdBy: createdBy,
      title: title,
      occurredAt: DateTime(2026, 10, 5),
    );

    testWidgets('tapping your own log opens it for editing', (tester) async {
      await addLog('Ate a sock', createdBy: 'u1');

      await pumpLogs(tester);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ate a sock'));
      await tester.pumpAndSettle();

      final screen = tester.widget<LogSymptomScreen>(find.byType(LogSymptomScreen));
      expect((screen.householdId, screen.petId, screen.log?.title), ('h1', 'p1', 'Ate a sock'));
    });

    testWidgets("members can't open someone else's log", (tester) async {
      await addLog('Limping', createdBy: 'u2');

      await pumpLogs(tester);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Limping'));
      await tester.pumpAndSettle();

      expect(find.byType(LogSymptomScreen), findsNothing);
    });

    testWidgets("admins can open anyone's log", (tester) async {
      await addLog('Limping', createdBy: 'u2');

      await pumpLogs(tester, isAdmin: true);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Limping'));
      await tester.pumpAndSettle();

      expect(tester.widget<LogSymptomScreen>(find.byType(LogSymptomScreen)).log?.title, 'Limping');
    });

    testWidgets('catalog logs, which the form has no fields for, do not open', (tester) async {
      final repository = MockSymptomLogRepository();
      when(() => repository.watchLogs(householdId: 'h1', petId: 'p1')).thenAnswer(
        (_) => Stream.value([
          SymptomLog(id: 'l1', symptom: 'vomit', createdBy: 'u1', occurredAt: DateTime(2026)),
        ]),
      );

      await pumpLogs(tester, repository: repository, isAdmin: true);
      await tester.pumpAndSettle();
      await tester.tap(find.text('vomit'));
      await tester.pumpAndSettle();

      expect(find.byType(LogSymptomScreen), findsNothing);
    });
  });
}
