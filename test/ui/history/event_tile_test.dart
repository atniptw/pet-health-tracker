import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_health_tracker/domain/built_in_event_types.dart';
import 'package:pet_health_tracker/domain/event_type.dart';
import 'package:pet_health_tracker/domain/medical_event.dart';
import 'package:pet_health_tracker/ui/history/event_tile.dart';

import '../../support/screen_checks.dart';

final seizure = builtInEventTypes.firstWhere((t) => t.id == 'seizure');

/// 9:30 PM on Nov 12 in the tests' America/Chicago time zone.
final occurredAt = DateTime.utc(2026, 11, 13, 3, 30);

MedicalEvent event({Map<String, Object> details = const {}, String? note}) => MedicalEvent(
  id: 'e1',
  petId: 'rex',
  typeId: seizure.id,
  occurredAt: occurredAt,
  details: details,
  note: note,
  createdAt: occurredAt,
  updatedAt: occurredAt,
);

Future<void> pumpTile(WidgetTester tester, MedicalEvent e, {EventType? type, Duration? gap}) =>
    tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [EventTile(event: e, type: type ?? seizure, gap: gap)],
          ),
        ),
      ),
    );

String tileText(WidgetTester tester) => tester
    .widgetList<Text>(find.descendant(of: find.byType(EventTile), matching: find.byType(Text)))
    .map((t) => t.data)
    .join('\n');

void main() {
  testWidgets('001-FR-008: the date and time in local time, the type, its details and the note', (
    tester,
  ) async {
    await pumpTile(
      tester,
      event(details: {'duration': 135, 'kind': 'grand_mal'}, note: 'After dinner'),
    );

    expect(
      tileText(tester),
      'Seizure\nNov 12, 2026 9:30 PM\nKind: Grand mal\nHow long it lasted: 2 min 15 s\n'
      'After dinner',
    );
    await expectAccessible(tester);
  });

  testWidgets('001-FR-008: unanswered details and an empty note are left out', (tester) async {
    await pumpTile(tester, event(details: {'duration': 40}));

    expect(tileText(tester), 'Seizure\nNov 12, 2026 9:30 PM\nHow long it lasted: 40 s');
  });

  testWidgets('001-FR-008: a custom type shows its name with no details', (tester) async {
    const limping = EventType(id: 'c1', name: 'Limping', builtIn: false, removed: true);

    await pumpTile(tester, event(), type: limping);

    expect(tileText(tester), 'Limping\nNov 12, 2026 9:30 PM');
  });

  testWidgets('001-US2-S2: an earlier event of the type → "<gap> since the previous one"', (
    tester,
  ) async {
    await pumpTile(tester, event(note: 'Short one'), gap: const Duration(days: 3, hours: 5));

    expect(find.text('3 days since the previous one'), findsOneWidget);
    expect(tileText(tester).split('\n').last, '3 days since the previous one');
    await expectAccessible(tester);
  });

  testWidgets('001-US2-S2: the first of a type → no gap shown', (tester) async {
    await pumpTile(tester, event());

    expect(find.textContaining('since the previous one'), findsNothing);
  });
}
