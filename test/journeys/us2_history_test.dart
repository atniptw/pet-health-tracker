import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_health_tracker/app.dart';
import 'package:pet_health_tracker/domain/pet.dart';
import 'package:pet_health_tracker/ui/history/event_tile.dart';
import 'package:pet_health_tracker/ui/history/type_summary.dart';

import '../support/robot.dart';
import '../support/test_app.dart';

void main() {
  testWidgets('001-US2-S1 001-SC-003: log Vomiting for Rex three times, then the history shows '
      'them newest first with the gaps, "3 times" and the average, and the counts follow the '
      'period', (tester) async {
    final app = await openTestApp(now: DateTime(2026, 12, 31, 12));
    final robot = Robot(tester);
    await tester.pumpWidget(
      App(pets: app.pets, eventTypes: app.eventTypes, events: app.events, clock: app.clock),
    );
    await tester.pumpAndSettle();
    await robot.addPet('Rex', Species.dog);

    await robot.logEvent('Vomiting', at: DateTime(2026, 12, 1, 9));
    await robot.logEvent('Vomiting', at: DateTime(2026, 12, 21, 9));
    await robot.logEvent('Vomiting', at: DateTime(2026, 12, 31, 9));
    await robot.openHistory('Rex');

    expect(find.widgetWithText(AppBar, 'Rex'), findsOneWidget);
    final tiles = [
      for (final tile in find.byType(EventTile).evaluate())
        tester
            .widgetList<Text>(
              find.descendant(of: find.byWidget(tile.widget), matching: find.byType(Text)),
            )
            .map((text) => text.data)
            .join('\n'),
    ];
    expect(tiles, [
      'Vomiting\nDec 31, 2026 9:00 AM\n10 days since the previous one',
      'Vomiting\nDec 21, 2026 9:00 AM\n20 days since the previous one',
      'Vomiting\nDec 1, 2026 9:00 AM',
    ]);
    Finder inSummary(String text) =>
        find.descendant(of: find.byType(TypeSummaryList), matching: find.text(text));
    expect(inSummary('3 times'), findsOneWidget);
    expect(inSummary('about every 15.0 days'), findsOneWidget);
    expect(inSummary('last 3 hours ago'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, '30 days'));
    await tester.pumpAndSettle();
    expect(inSummary('2 times'), findsOneWidget);
    expect(inSummary('about every 10.0 days'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, 'All time'));
    await tester.pumpAndSettle();
    expect(inSummary('3 times'), findsOneWidget);
  });
}
