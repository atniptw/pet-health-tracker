import 'package:flutter/material.dart';

import '../../data/symptom_catalog.dart';

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// When a log happened, short: the time of day for today, "Yesterday", or a
/// date such as "Mon 3 Oct". Dates in another year end with the year.
String formatRecentTime(BuildContext context, DateTime occurredAt, {DateTime? now}) {
  now ??= DateTime.now();
  final day = DateUtils.dateOnly(occurredAt);
  final today = DateUtils.dateOnly(now);
  if (day == today) {
    return MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay.fromDateTime(occurredAt),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );
  }
  if (day == DateUtils.addDaysToDate(today, -1)) return 'Yesterday';
  final date = '${_weekdays[day.weekday - 1]} ${day.day} ${_months[day.month - 1]}';
  return day.year == today.year ? date : '$date ${day.year}';
}

/// A catalog log's answers in the catalog's order, such as "Watery ·
/// Straining". Yes/no questions show their label when answered yes. Answers
/// to questions the catalog doesn't have are left out.
String summarizeAnswers(CatalogSymptom symptom, Map<String, dynamic> answers) {
  String option(CatalogQuestion question, Object? key) {
    for (final option in question.options) {
      if (option.key == key) return option.label;
    }
    return '$key';
  }

  return [
    for (final question in symptom.questions)
      if (answers[question.key] case final answer?)
        switch (question.type) {
          QuestionType.yesNo => answer == true ? question.label : null,
          QuestionType.singleChoice => option(question, answer),
          QuestionType.multipleChoice => [
            for (final key in answer as List) option(question, key),
          ].join(', '),
          QuestionType.number => question.unit == null ? '$answer' : '$answer ${question.unit}',
          QuestionType.text => '$answer',
        },
  ].nonNulls.where((part) => part.isNotEmpty).join(' · ');
}
