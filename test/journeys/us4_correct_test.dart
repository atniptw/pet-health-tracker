import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_health_tracker/app.dart';
import 'package:pet_health_tracker/domain/pet.dart';
import 'package:pet_health_tracker/ui/history/event_tile.dart';
import 'package:pet_health_tracker/ui/history/type_summary.dart';

import '../support/pickers.dart';
import '../support/robot.dart';
import '../support/test_app.dart';

void main() {
  testWidgets('001-US4-S1 001-US4-S2: log Vomiting twice, move the older one back a day and see '
      'the gap grow, then delete it and see the count drop to 1 with no gap', (tester) async {
    final app = await openTestApp(now: DateTime(2026, 11, 14, 12));
    final robot = Robot(tester);
    await tester.pumpWidget(
      App(pets: app.pets, eventTypes: app.eventTypes, events: app.events, clock: app.clock),
    );
    await tester.pumpAndSettle();
    await robot.addPet('Rex', Species.dog);
    await robot.logEvent('Vomiting', at: DateTime(2026, 11, 10, 8));
    await robot.logEvent('Vomiting', at: DateTime(2026, 11, 12, 8));
    await robot.openHistory('Rex');
    List<String> tiles() => [
      for (final tile in find.byType(EventTile).evaluate())
        tester
            .widgetList<Text>(
              find.descendant(of: find.byWidget(tile.widget), matching: find.byType(Text)),
            )
            .map((text) => text.data)
            .join('\n'),
    ];
    Finder inSummary(String text) =>
        find.descendant(of: find.byType(TypeSummaryList), matching: find.text(text));
    Future<void> openOlder() async {
      await tester.tap(
        find.ancestor(of: find.textContaining('Nov'), matching: find.byType(EventTile)).last,
      );
      await tester.pumpAndSettle();
    }

    expect(tiles().first, endsWith('2 days since the previous one'));

    await openOlder();
    await openPickers(tester);
    await pickDay(tester, 9);
    await pickTime(tester, 8, 0, 'AM');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    expect(tiles(), [
      'Vomiting\nNov 12, 2026 8:00 AM\n3 days since the previous one',
      'Vomiting\nNov 9, 2026 8:00 AM',
    ]);

    await openOlder();
    await tester.tap(find.widgetWithText(TextButton, 'Delete'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(TextButton, 'Delete'),
      ),
    );
    await tester.pumpAndSettle();
    expect(tiles(), ['Vomiting\nNov 12, 2026 8:00 AM']);
    expect(inSummary('1 time'), findsOneWidget);
    expect(find.textContaining('about every'), findsNothing);
  });
}
