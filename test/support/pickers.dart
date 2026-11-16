import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_health_tracker/ui/common/date_time_field.dart';

/// Taps the "When" field, opening its date picker.
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
