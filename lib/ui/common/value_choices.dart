import 'package:flutter/material.dart';

/// A chip per value in [values], named by [label], with [picked] highlighted.
/// Tapping a chip, the picked one included, reports its value.
class ValueChoices<T> extends StatelessWidget {
  const ValueChoices({
    super.key,
    required this.values,
    required this.label,
    required this.picked,
    required this.onPicked,
  });

  final List<T> values;
  final String Function(T value) label;
  final T picked;
  final ValueChanged<T> onPicked;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    children: [
      for (final value in values)
        ChoiceChip(
          label: Text(label(value)),
          selected: value == picked,
          onSelected: (_) => onPicked(value),
        ),
    ],
  );
}
