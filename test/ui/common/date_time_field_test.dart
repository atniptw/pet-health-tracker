import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_health_tracker/ui/common/date_time_field.dart';

import '../../support/screen_checks.dart';

final now = DateTime(2026, 11, 14, 12);

/// The field on a screen whose clock reads [now], keeping each reported
/// moment in [reported].
Future<List<DateTime>> pumpField(WidgetTester tester, {DateTime? value}) async {
  final reported = <DateTime>[];
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: StatefulBuilder(
          builder: (context, setState) => DateTimeField(
            clock: () => now,
            value: value,
            onChanged: (moment) => setState(() {
              reported.add(moment);
              value = moment;
            }),
          ),
        ),
      ),
    ),
  );
  return reported;
}

Future<void> openPickers(WidgetTester tester) async {
  await tester.tap(find.byType(DateTimeField));
  await tester.pumpAndSettle();
}

/// In the open date picker, taps [day] of the shown month and "OK".
Future<void> pickDay(WidgetTester tester, int day) async {
  await tester.tap(find.text('$day'));
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
}

/// In the open time picker, types [hour] (1–12), [minute] and the [period]
/// ("AM" or "PM"), and taps "OK".
Future<void> pickTime(WidgetTester tester, int hour, int minute, String period) async {
  await tester.tap(find.byIcon(Icons.keyboard_outlined));
  await tester.pumpAndSettle();
  final fields = find.descendant(of: find.byType(Dialog), matching: find.byType(TextField));
  await tester.enterText(fields.at(0), '$hour');
  await tester.enterText(fields.at(1), minute.toString().padLeft(2, '0'));
  await tester.tap(find.text(period));
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('001-FR-003: shows "Now" until changed', (tester) async {
    final reported = await pumpField(tester);

    expect(find.text('When'), findsOneWidget);
    expect(find.text('Now'), findsOneWidget);
    expect(reported, isEmpty);
  });

  testWidgets('001-US1-S4: an event a while ago → its date and time can be set', (tester) async {
    final reported = await pumpField(tester);

    await openPickers(tester);
    await pickDay(tester, 13);
    await pickTime(tester, 9, 30, 'PM');

    expect(reported, [DateTime(2026, 11, 13, 21, 30)]);
    expect(find.textContaining('Nov 13, 2026'), findsOneWidget);
    expect(find.textContaining('9:30'), findsOneWidget);
    expect(find.text('Now'), findsNothing);
  });

  testWidgets('001-FR-003: the date picker stops at today', (tester) async {
    await pumpField(tester);

    await openPickers(tester);

    final picker = tester.widget<DatePickerDialog>(find.byType(DatePickerDialog));
    expect(picker.lastDate, DateTime(2026, 11, 14));
    expect(picker.initialDate, DateTime(2026, 11, 14));
  });

  testWidgets('001-FR-003: an earlier time today is accepted', (tester) async {
    final reported = await pumpField(tester);

    await openPickers(tester);
    await pickDay(tester, 14);
    await pickTime(tester, 8, 5, 'AM');

    expect(reported, [DateTime(2026, 11, 14, 8, 5)]);
    expect(find.textContaining('8:05'), findsOneWidget);
  });

  testWidgets('001-FR-003: a time after now is not accepted', (tester) async {
    final reported = await pumpField(tester);

    await openPickers(tester);
    await pickDay(tester, 14);
    await pickTime(tester, 1, 0, 'PM');

    expect(reported, isEmpty);
    expect(find.text('Now'), findsOneWidget);
    expect(find.text('That time is in the future'), findsOneWidget);
  });

  testWidgets('001-FR-003: a past time after a future one clears the message', (tester) async {
    final reported = await pumpField(tester);
    await openPickers(tester);
    await pickDay(tester, 14);
    await pickTime(tester, 1, 0, 'PM');

    await openPickers(tester);
    await pickDay(tester, 12);
    await pickTime(tester, 1, 0, 'PM');

    expect(reported, [DateTime(2026, 11, 12, 13)]);
    expect(find.text('That time is in the future'), findsNothing);
  });

  testWidgets('001-FR-003: cancelling either picker keeps the time', (tester) async {
    final reported = await pumpField(tester);

    await openPickers(tester);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await openPickers(tester);
    await pickDay(tester, 10);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(reported, isEmpty);
    expect(find.text('Now'), findsOneWidget);
  });

  testWidgets('001-FR-003: a set time opens the pickers at it', (tester) async {
    await pumpField(tester, value: DateTime(2026, 10, 2, 7, 45));

    expect(find.textContaining('Oct 2, 2026'), findsOneWidget);
    await openPickers(tester);
    final datePicker = tester.widget<DatePickerDialog>(find.byType(DatePickerDialog));
    expect(datePicker.initialDate, DateTime(2026, 10, 2));
    await pickDay(tester, 2);
    final timePicker = tester.widget<TimePickerDialog>(find.byType(TimePickerDialog));
    expect(timePicker.initialTime, const TimeOfDay(hour: 7, minute: 45));
  });

  testWidgets('001-FR-003: a stored UTC time is shown and picked in local time', (tester) async {
    await pumpField(tester, value: DateTime.utc(2026, 11, 14, 3, 30));

    expect(find.textContaining('Nov 13, 2026'), findsOneWidget);
    expect(find.textContaining(RegExp(r'9:30\sPM')), findsOneWidget);
    await openPickers(tester);
    final datePicker = tester.widget<DatePickerDialog>(find.byType(DatePickerDialog));
    expect(datePicker.initialDate, DateTime(2026, 11, 13));
    await pickDay(tester, 13);
    final timePicker = tester.widget<TimePickerDialog>(find.byType(TimePickerDialog));
    expect(timePicker.initialTime, const TimeOfDay(hour: 21, minute: 30));
  });

  testWidgets('001-FR-003: the field is accessible', (tester) async {
    await pumpField(tester);

    await expectAccessible(tester);
  });
}
