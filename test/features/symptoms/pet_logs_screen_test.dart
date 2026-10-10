import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pet_health_tracker/core/firebase_providers.dart';
import 'package:pet_health_tracker/data/household_repository.dart';
import 'package:pet_health_tracker/data/pet.dart';
import 'package:pet_health_tracker/data/symptom_catalog.dart';
import 'package:pet_health_tracker/data/symptom_log.dart';
import 'package:pet_health_tracker/data/symptom_log_repository.dart';
import 'package:pet_health_tracker/features/symptoms/edit_log_screen.dart';
import 'package:pet_health_tracker/features/symptoms/pet_logs_screen.dart';
import 'package:pet_health_tracker/features/symptoms/symptom_details_screen.dart';
import 'package:pet_health_tracker/features/symptoms/symptom_providers.dart';

import '../../helpers.dart';

class MockSymptomLogRepository extends Mock implements SymptomLogRepository {}

void main() {
  const boogie = Pet(id: 'p1', name: 'Boogie', species: Species.dog);
  const catalog = SymptomCatalog([CatalogSymptom(key: 'vomit', label: 'Vomit')]);

  late SymptomLogRepository logs;
  late FakeFirebaseFirestore membersFirestore;

  setUp(() {
    logs = SymptomLogRepository(FakeFirebaseFirestore());
    membersFirestore = FakeFirebaseFirestore();
  });

  Future<void> pumpLogs(
    WidgetTester tester, {
    SymptomLogRepository? repository,
    bool isAdmin = false,
    bool hasOtherMembers = false,
  }) {
    return tester.pumpScoped(
      PetLogsScreen(
        householdId: 'h1',
        pet: boogie,
        uid: 'u1',
        isAdmin: isAdmin,
        hasOtherMembers: hasOtherMembers,
      ),
      overrides: [
        householdRepositoryProvider.overrideWithValue(HouseholdRepository(membersFirestore)),
        symptomLogRepositoryProvider.overrideWithValue(repository ?? logs),
        symptomCatalogProvider.overrideWith((ref) => Stream.value(catalog)),
      ],
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

  testWidgets('separates logs with dividers', (tester) async {
    for (final title in ['Ate a sock', 'Limping', 'Sneezing']) {
      await logs.addOtherLog(
        householdId: 'h1',
        petId: 'p1',
        createdBy: 'u1',
        title: title,
        occurredAt: DateTime(2026, 10, 5, 9, 5),
      );
    }

    await pumpLogs(tester);
    await tester.pumpAndSettle();

    expect(find.byType(Divider), findsNWidgets(2));
  });

  testWidgets('titles a catalog log with its catalog label', (tester) async {
    final repository = MockSymptomLogRepository();
    when(() => repository.watchLogs(householdId: 'h1', petId: 'p1')).thenAnswer(
      (_) => Stream.value([
        SymptomLog(id: 'l1', symptom: 'vomit', createdBy: 'u2', occurredAt: DateTime(2026)),
      ]),
    );

    await pumpLogs(tester, repository: repository);
    await tester.pumpAndSettle();

    expect(find.text('Vomit'), findsOneWidget);
  });

  testWidgets('falls back to the symptom key for a symptom the catalog lacks', (tester) async {
    final repository = MockSymptomLogRepository();
    when(() => repository.watchLogs(householdId: 'h1', petId: 'p1')).thenAnswer(
      (_) => Stream.value([
        SymptomLog(id: 'l1', symptom: 'bloat', createdBy: 'u2', occurredAt: DateTime(2026)),
      ]),
    );

    await pumpLogs(tester, repository: repository);
    await tester.pumpAndSettle();

    expect(find.text('bloat'), findsOneWidget);
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

  testWidgets('has no button to log a symptom', (tester) async {
    await pumpLogs(tester);
    await tester.pumpAndSettle();

    expect(find.byType(FloatingActionButton), findsNothing);
  });

  group('who logged it', () {
    Future<void> addLog(String title, {required String createdBy}) => logs.addOtherLog(
      householdId: 'h1',
      petId: 'p1',
      createdBy: createdBy,
      title: title,
      occurredAt: DateTime(2026, 10, 5, 9, 5),
    );

    setUp(() async {
      await membersFirestore.doc('households/h1/members/u1').set({'name': 'Tom'});
      await membersFirestore.doc('households/h1/members/u2').set({'name': 'Sam'});
    });

    testWidgets('shows names when the household has other members', (tester) async {
      await addLog('Ate a sock', createdBy: 'u1');
      await addLog('Limping', createdBy: 'u2');

      await pumpLogs(tester, hasOtherMembers: true);
      await tester.pumpAndSettle();

      expect(find.text('Monday, October 5, 2026 · 9:05 AM · Tom'), findsOneWidget);
      expect(find.text('Monday, October 5, 2026 · 9:05 AM · Sam'), findsOneWidget);
    });

    testWidgets('leaves your own name off when you are the only member', (tester) async {
      await addLog('Ate a sock', createdBy: 'u1');

      await pumpLogs(tester);
      await tester.pumpAndSettle();

      expect(find.text('Monday, October 5, 2026 · 9:05 AM'), findsOneWidget);
    });

    testWidgets("still names a former member's logs when you are the only member", (tester) async {
      await addLog('Limping', createdBy: 'u2');

      await pumpLogs(tester);
      await tester.pumpAndSettle();

      expect(find.text('Monday, October 5, 2026 · 9:05 AM · Sam'), findsOneWidget);
    });

    testWidgets('shows no name for someone who has not given one', (tester) async {
      await addLog('Limping', createdBy: 'u3');

      await pumpLogs(tester, hasOtherMembers: true);
      await tester.pumpAndSettle();

      expect(find.text('Monday, October 5, 2026 · 9:05 AM'), findsOneWidget);
    });
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

      final screen = tester.widget<EditLogScreen>(find.byType(EditLogScreen));
      expect((screen.householdId, screen.petId, screen.log.title), ('h1', 'p1', 'Ate a sock'));
    });

    testWidgets("members can't open someone else's log", (tester) async {
      await addLog('Limping', createdBy: 'u2');

      await pumpLogs(tester);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Limping'));
      await tester.pumpAndSettle();

      expect(find.byType(EditLogScreen), findsNothing);
    });

    testWidgets("admins can open anyone's log", (tester) async {
      await addLog('Limping', createdBy: 'u2');

      await pumpLogs(tester, isAdmin: true);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Limping'));
      await tester.pumpAndSettle();

      expect(tester.widget<EditLogScreen>(find.byType(EditLogScreen)).log.title, 'Limping');
    });

    Future<void> tapCatalogLog(WidgetTester tester, {required bool isAdmin}) async {
      final repository = MockSymptomLogRepository();
      when(() => repository.watchLogs(householdId: 'h1', petId: 'p1')).thenAnswer(
        (_) => Stream.value([
          SymptomLog(id: 'l1', symptom: 'vomit', createdBy: 'u2', occurredAt: DateTime(2026)),
        ]),
      );

      await pumpLogs(tester, repository: repository, isAdmin: isAdmin);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Vomit'));
      await tester.pumpAndSettle();
    }

    testWidgets('catalog logs open their details', (tester) async {
      await tapCatalogLog(tester, isAdmin: true);

      final screen = tester.widget<SymptomDetailsScreen>(find.byType(SymptomDetailsScreen));
      expect(
        (screen.householdId, screen.petId, screen.petName, screen.log.id),
        ('h1', 'p1', 'Boogie', 'l1'),
      );
      expect(find.byType(EditLogScreen), findsNothing);
    });

    testWidgets("members can't open someone else's catalog log", (tester) async {
      await tapCatalogLog(tester, isAdmin: false);

      expect(find.byType(SymptomDetailsScreen), findsNothing);
    });
  });
}
