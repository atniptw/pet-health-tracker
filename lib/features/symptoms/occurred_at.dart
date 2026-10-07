import 'package:flutter/material.dart';

/// When a symptom happened, as a full date and time of day.
String formatOccurredAt(BuildContext context, DateTime occurredAt) {
  final localizations = MaterialLocalizations.of(context);
  return '${localizations.formatFullDate(occurredAt)} · '
      '${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(occurredAt))}';
}

/// Asks for a date, then a time of day, starting from [initial]. Null when
/// either picker is cancelled.
Future<DateTime?> pickOccurredAt(BuildContext context, DateTime initial) async {
  final now = DateTime.now();
  final date = await showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: DateTime(now.year - 50),
    lastDate: now,
    helpText: 'When did it happen?',
  );
  if (date == null || !context.mounted) return null;
  final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(initial));
  if (time == null) return null;
  return DateTime(date.year, date.month, date.day, time.hour, time.minute);
}
