import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A duration question: [label] above "Minutes" and "Seconds" number fields.
/// Each edit reports the total in whole seconds, or null when both are empty
/// or zero, so the question is skipped. Seconds over 59 are added as they
/// are (D-008).
class DurationField extends StatefulWidget {
  const DurationField({super.key, required this.label, required this.onChanged});

  final String label;

  /// Whole seconds, at least 1, or null when unanswered.
  final ValueChanged<int?> onChanged;

  @override
  State<DurationField> createState() => _DurationFieldState();
}

class _DurationFieldState extends State<DurationField> {
  final _minutes = TextEditingController();
  final _seconds = TextEditingController();

  @override
  void dispose() {
    _minutes.dispose();
    _seconds.dispose();
    super.dispose();
  }

  void _report() {
    final total = (int.tryParse(_minutes.text) ?? 0) * 60 + (int.tryParse(_seconds.text) ?? 0);
    widget.onChanged(total >= 1 ? total : null);
  }

  Widget _number(TextEditingController controller, String label, int maxDigits) {
    return Expanded(
      child: TextField(
        controller: controller,
        decoration: InputDecoration(labelText: label),
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(maxDigits),
        ],
        onChanged: (_) => _report(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(widget.label, style: Theme.of(context).textTheme.titleSmall),
        Row(
          children: [
            _number(_minutes, 'Minutes', 3),
            const SizedBox(width: 16),
            _number(_seconds, 'Seconds', 2),
          ],
        ),
      ],
    );
  }
}
