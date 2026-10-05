import 'package:flutter/material.dart';

/// When a symptom happened, as a full date and time of day.
String formatOccurredAt(BuildContext context, DateTime occurredAt) {
  final localizations = MaterialLocalizations.of(context);
  return '${localizations.formatFullDate(occurredAt)} · '
      '${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(occurredAt))}';
}
