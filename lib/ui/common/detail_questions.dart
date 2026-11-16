import 'package:flutter/material.dart';

import '../../domain/event_type.dart';
import 'duration_field.dart';

/// A type's optional detail questions, each with the input its kind needs.
/// Each answer or skip reports every answered question, keyed by question id,
/// in the shape `validDetails` accepts; a skipped question has no key.
class DetailQuestions extends StatefulWidget {
  const DetailQuestions({super.key, required this.questions, required this.onChanged});

  final List<DetailQuestion> questions;

  final ValueChanged<Map<String, Object>> onChanged;

  @override
  State<DetailQuestions> createState() => _DetailQuestionsState();
}

class _DetailQuestionsState extends State<DetailQuestions> {
  final _answers = <String, Object>{};

  void _report() => widget.onChanged(Map.unmodifiable(_answers));

  void _answer(String id, Object? answer) {
    setState(() {
      if (answer == null) {
        _answers.remove(id);
      } else {
        _answers[id] = answer;
      }
    });
    _report();
  }

  Widget _input(DetailQuestion question) => switch (question) {
    ChoiceQuestion() => _ChoiceChips(
      question: question,
      picked: _answers[question.id],
      onPicked: (option) => _answer(question.id, option),
    ),
    DurationQuestion() => DurationField(
      label: question.label,
      onChanged: (seconds) => _answer(question.id, seconds),
    ),
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final question in widget.questions)
          Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: _input(question)),
      ],
    );
  }
}

/// [question]'s label above a chip per option; tapping the picked chip again
/// clears it.
class _ChoiceChips extends StatelessWidget {
  const _ChoiceChips({required this.question, required this.picked, required this.onPicked});

  final ChoiceQuestion question;

  /// The picked option's id, or null when none is picked.
  final Object? picked;

  final ValueChanged<String?> onPicked;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(question.label, style: Theme.of(context).textTheme.titleSmall),
        Wrap(
          spacing: 8,
          children: [
            for (final option in question.options)
              ChoiceChip(
                label: Text(option.label),
                selected: option.id == picked,
                onSelected: (selected) => onPicked(selected ? option.id : null),
              ),
          ],
        ),
      ],
    );
  }
}
