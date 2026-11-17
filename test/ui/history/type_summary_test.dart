import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_health_tracker/domain/medical_event.dart';
import 'package:pet_health_tracker/ui/history/type_summary.dart';

import '../../support/screen_checks.dart';

/// Noon on Nov 14, 2026 in the tests' America/Chicago time zone.
final now = DateTime(2026, 11, 14, 12);

const names = {'vomiting': 'Vomiting', 'seizure': 'Seizure', 'c1': 'Limping'};

var _ids = 0;

/// An event of [typeId] that happened [ago] before [now].
MedicalEvent event(String typeId, Duration ago) {
  final at = now.subtract(ago).toUtc();
  return MedicalEvent(
    id: 'e${++_ids}',
    petId: 'rex',
    typeId: typeId,
    occurredAt: at,
    createdAt: at,
    updatedAt: at,
  );
}

Future<void> pumpSummary(WidgetTester tester, List<MedicalEvent> events, {DateTime? at}) =>
    tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              TypeSummaryList(events: events, now: at ?? now, typeName: (id) => names[id]!),
            ],
          ),
        ),
      ),
    );

bool picked(WidgetTester tester, String label) =>
    tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, label)).selected;

/// The texts of the row for the type named [name].
List<String?> rowText(WidgetTester tester, String name) => tester
    .widgetList<Text>(
      find.descendant(of: find.widgetWithText(ListTile, name), matching: find.byType(Text)),
    )
    .map((t) => t.data)
    .toList();

void main() {
  testWidgets('001-FR-010: the periods are offered, with "90 days" picked first', (tester) async {
    await pumpSummary(tester, [
      event('vomiting', const Duration(days: 89)),
      event('vomiting', const Duration(days: 91)),
    ]);

    expect(picked(tester, '30 days'), isFalse);
    expect(picked(tester, '90 days'), isTrue);
    expect(picked(tester, '12 months'), isFalse);
    expect(picked(tester, 'All time'), isFalse);
    expect(find.text('1 time'), findsOneWidget);
    await expectAccessible(tester);
  });

  testWidgets('001-FR-010: picking another period counts over that period', (tester) async {
    await pumpSummary(tester, [
      event('vomiting', const Duration(days: 10)),
      event('vomiting', const Duration(days: 60)),
      event('vomiting', const Duration(days: 200)),
      event('vomiting', const Duration(days: 400)),
    ]);
    expect(find.text('2 times'), findsOneWidget);

    await tester.tap(find.text('30 days'));
    await tester.pump();
    expect(picked(tester, '30 days'), isTrue);
    expect(picked(tester, '90 days'), isFalse);
    expect(find.text('1 time'), findsOneWidget);

    await tester.tap(find.text('12 months'));
    await tester.pump();
    expect(find.text('3 times'), findsOneWidget);

    await tester.tap(find.text('All time'));
    await tester.pump();
    expect(find.text('4 times'), findsOneWidget);
  });

  testWidgets('001-FR-010: tapping the picked period keeps it picked', (tester) async {
    await pumpSummary(tester, [event('vomiting', const Duration(days: 10))]);

    await tester.tap(find.text('90 days'));
    await tester.pump();

    expect(picked(tester, '90 days'), isTrue);
  });

  testWidgets('001-US2-S3: per type, its name, the count, the average time between and the '
      'last one', (tester) async {
    await pumpSummary(tester, [
      event('vomiting', const Duration(hours: 5)),
      event('vomiting', const Duration(days: 2, hours: 5)),
      event('vomiting', const Duration(days: 7, hours: 5)),
    ]);

    expect(rowText(tester, 'Vomiting'), [
      'Vomiting',
      '3 times',
      'about every 3.5 days',
      'last 5 hours ago',
    ]);
    await expectAccessible(tester);
  });

  testWidgets('001-US2-S3: the type that happened most recently comes first (D-021)', (
    tester,
  ) async {
    await pumpSummary(tester, [
      event('seizure', const Duration(days: 3)),
      event('vomiting', const Duration(days: 1)),
      event('c1', const Duration(days: 5)),
      event('seizure', const Duration(days: 20)),
    ]);

    final titles = tester
        .widgetList<ListTile>(find.byType(ListTile))
        .map((tile) => (tile.title! as Text).data);
    expect(titles, ['Vomiting', 'Seizure', 'Limping']);
    expect(rowText(tester, 'Seizure'), [
      'Seizure',
      '2 times',
      'about every 17.0 days',
      'last 3 days ago',
    ]);
  });

  testWidgets('001-US2-S4: one event of a type → "1 time", no time between and no error', (
    tester,
  ) async {
    await pumpSummary(tester, [event('seizure', const Duration(minutes: 30))]);

    expect(rowText(tester, 'Seizure'), ['Seizure', '1 time', 'last 30 minutes ago']);
    expect(find.textContaining('about every'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('001-FR-010: no events in the period → "Nothing logged in this period"', (
    tester,
  ) async {
    await pumpSummary(tester, [event('vomiting', const Duration(days: 100))]);

    expect(find.text('Nothing logged in this period'), findsOneWidget);
    expect(find.byType(ListTile), findsNothing);
    await expectAccessible(tester);

    await tester.tap(find.text('All time'));
    await tester.pump();
    expect(find.text('Nothing logged in this period'), findsNothing);
    expect(find.text('1 time'), findsOneWidget);
  });

  testWidgets('001-FR-010: a pet with no events → "Nothing logged in this period"', (tester) async {
    await pumpSummary(tester, []);

    expect(find.text('Nothing logged in this period'), findsOneWidget);
  });

  testWidgets('001-FR-010: new events and a later now update the summary, keeping the period', (
    tester,
  ) async {
    final first = event('vomiting', const Duration(days: 200));
    await pumpSummary(tester, [first]);
    await tester.tap(find.text('All time'));
    await tester.pump();

    await pumpSummary(tester, [first, event('vomiting', const Duration(days: 1))]);
    expect(picked(tester, 'All time'), isTrue);
    expect(find.text('2 times'), findsOneWidget);
    expect(find.text('last 24 hours ago'), findsOneWidget);

    await pumpSummary(tester, [
      first,
      event('vomiting', const Duration(days: 1)),
    ], at: now.add(const Duration(days: 2)));
    expect(find.text('last 3 days ago'), findsOneWidget);
  });
}
