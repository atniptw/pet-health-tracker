import 'package:flutter/material.dart';

import '../../domain/event_type.dart';

/// A large button per type in [types], two to a row, in the given order,
/// then "Something else".
class TypeGrid extends StatelessWidget {
  const TypeGrid({
    super.key,
    required this.types,
    required this.onTap,
    required this.onSomethingElse,
  });

  /// The offered types.
  final List<EventType> types;

  /// Runs with the tapped button's type.
  final ValueChanged<EventType> onTap;

  /// Runs when "Something else" is tapped.
  final VoidCallback onSomethingElse;

  static const _spacing = 8.0;

  /// The least height of a button.
  static const minButtonHeight = 72.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - _spacing) / 2;
        return Wrap(
          spacing: _spacing,
          runSpacing: _spacing,
          children: [
            for (final type in types)
              _sized(
                width,
                FilledButton.tonal(
                  onPressed: () => onTap(type),
                  child: Text(type.name, textAlign: TextAlign.center),
                ),
              ),
            _sized(
              width,
              OutlinedButton(
                onPressed: onSomethingElse,
                child: const Text('Something else', textAlign: TextAlign.center),
              ),
            ),
          ],
        );
      },
    );
  }

  static Widget _sized(double width, Widget button) => SizedBox(
    width: width,
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: minButtonHeight),
      child: button,
    ),
  );
}
