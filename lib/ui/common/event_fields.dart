import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/repositories.dart';
import '../../domain/event_type.dart';
import 'date_time_field.dart';
import 'detail_questions.dart';

/// An event's "When", its type's detail questions and "Note (optional)",
/// each optional. The parent keeps what they hold.
class EventFields extends StatelessWidget {
  const EventFields({
    super.key,
    required this.clock,
    required this.when,
    required this.onWhenChanged,
    this.whenError,
    required this.questions,
    required this.onDetailsChanged,
    required this.note,
  });

  final Clock clock;

  /// The chosen moment; null means "Now".
  final DateTime? when;

  final ValueChanged<DateTime> onWhenChanged;

  /// An error to show under "When", such as one found on saving.
  final String? whenError;

  /// The type's questions, fixed for this widget's life.
  final List<DetailQuestion> questions;

  /// Every answered question, keyed by question id, after each change.
  final ValueChanged<Map<String, Object>> onDetailsChanged;

  /// The note as typed, up to the 1000 characters `validNote` takes.
  final TextEditingController note;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        DateTimeField(clock: clock, value: when, onChanged: onWhenChanged, errorText: whenError),
        DetailQuestions(questions: questions, onChanged: onDetailsChanged),
        TextField(
          controller: note,
          decoration: const InputDecoration(labelText: 'Note (optional)'),
          textCapitalization: TextCapitalization.sentences,
          minLines: 1,
          maxLines: 5,
          inputFormatters: [LengthLimitingTextInputFormatter(1000)],
        ),
      ],
    );
  }
}
