import 'package:flutter/material.dart';

import '../../domain/durations.dart';
import '../../domain/event_type.dart';
import '../../domain/medical_event.dart';
import '../common/date_time_field.dart';

/// One event in a pet's history: [type]'s name, then the date and time in
/// local time, each answered detail as "question: answer" in [type]'s
/// question order, the note, and "3 days since the previous one" when [gap],
/// the time since the previous event of the type, is given.
class EventTile extends StatelessWidget {
  const EventTile({super.key, required this.event, required this.type, this.gap});

  final MedicalEvent event;

  /// [event]'s type, removed or not.
  final EventType type;

  /// Null for the first event of its type.
  final Duration? gap;

  @override
  Widget build(BuildContext context) {
    final note = event.note;
    final gap = this.gap;
    return ListTile(
      title: Text(type.name),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(dateTimeText(event.occurredAt)),
          for (final question in type.questions)
            if (event.details[question.id] case final answer?)
              Text('${question.label}: ${question.describe(answer)}'),
          if (note != null) Text(note),
          if (gap != null) Text('${gapText(gap)} since the previous one'),
        ],
      ),
    );
  }
}
