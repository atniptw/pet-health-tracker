import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_health_tracker/ui/common/duration_field.dart';

import '../../support/screen_checks.dart';

/// The field labelled "How long it lasted", keeping each reported value in
/// the returned list.
Future<List<int?>> pumpField(WidgetTester tester) async {
  final reported = <int?>[];
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: DurationField(label: 'How long it lasted', onChanged: reported.add),
      ),
    ),
  );
  return reported;
}

Finder field(String label) => find.widgetWithText(TextField, label);

Future<void> enter(WidgetTester tester, {String? minutes, String? seconds}) async {
  if (minutes != null) await tester.enterText(field('Minutes'), minutes);
  if (seconds != null) await tester.enterText(field('Seconds'), seconds);
  await tester.pump();
}

void main() {
  testWidgets('001-US1-S7: shows the question with empty minutes and seconds', (tester) async {
    final reported = await pumpField(tester);

    expect(find.text('How long it lasted'), findsOneWidget);
    expect(field('Minutes'), findsOneWidget);
    expect(field('Seconds'), findsOneWidget);
    expect(tester.widget<TextField>(field('Minutes')).controller!.text, isEmpty);
    expect(tester.widget<TextField>(field('Seconds')).controller!.text, isEmpty);
    expect(reported, isEmpty);
  });

  testWidgets('001-US1-S7: 2 minutes → 120 seconds', (tester) async {
    final reported = await pumpField(tester);

    await enter(tester, minutes: '2');

    expect(reported.last, 120);
  });

  testWidgets('001-US1-S7: 1 minute 30 seconds → 90 seconds', (tester) async {
    final reported = await pumpField(tester);

    await enter(tester, minutes: '1', seconds: '30');

    expect(reported.last, 90);
  });

  testWidgets('001-US1-S7: seconds alone, 1 second → 1', (tester) async {
    final reported = await pumpField(tester);

    await enter(tester, seconds: '1');

    expect(reported.last, 1);
  });

  testWidgets('001-US1-S7: seconds over 59 are added up (D-008)', (tester) async {
    final reported = await pumpField(tester);

    await enter(tester, minutes: '1', seconds: '75');

    expect(reported.last, 135);
  });

  testWidgets('001-US1-S7: both zero → skipped (null)', (tester) async {
    final reported = await pumpField(tester);

    await enter(tester, minutes: '0', seconds: '00');

    expect(reported, isNotEmpty);
    expect(reported.last, isNull);
  });

  testWidgets('001-US1-S7: answered then emptied → skipped (null)', (tester) async {
    final reported = await pumpField(tester);
    await enter(tester, minutes: '3', seconds: '5');

    await enter(tester, minutes: '', seconds: '');

    expect(reported.last, isNull);
  });

  testWidgets('001-US1-S7: only digits are taken', (tester) async {
    final reported = await pumpField(tester);

    await enter(tester, minutes: '1.5', seconds: '-7');

    expect(tester.widget<TextField>(field('Minutes')).controller!.text, '15');
    expect(tester.widget<TextField>(field('Seconds')).controller!.text, '7');
    expect(reported.last, 15 * 60 + 7);
  });

  testWidgets('001-US1-S7: minutes take 3 digits, seconds 2 (D-008)', (tester) async {
    final reported = await pumpField(tester);

    await enter(tester, minutes: '12345', seconds: '999');

    expect(tester.widget<TextField>(field('Minutes')).controller!.text, '123');
    expect(tester.widget<TextField>(field('Seconds')).controller!.text, '99');
    expect(reported.last, 123 * 60 + 99);
  });

  testWidgets('001-US1-S7: the fields offer a number keyboard', (tester) async {
    await pumpField(tester);

    for (final label in ['Minutes', 'Seconds']) {
      expect(tester.widget<TextField>(field(label)).keyboardType, TextInputType.number);
    }
  });

  testWidgets('001-US1-S7: the field is accessible', (tester) async {
    await pumpField(tester);

    await expectAccessible(tester);
  });
}
