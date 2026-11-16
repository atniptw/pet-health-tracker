import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/repositories.dart';

/// The message for a time after now, on picking or on saving.
const futureTimeError = 'That time is in the future';

/// "When" an event happened: "Now" while [value] is null, otherwise [value]
/// in local time. Tapping opens the date picker, up to today, then the time
/// picker; a moment after [clock]'s now is not accepted. [errorText], such
/// as one found on saving, shows under the field.
class DateTimeField extends StatefulWidget {
  const DateTimeField({
    super.key,
    required this.clock,
    required this.value,
    required this.onChanged,
    this.errorText,
  });

  final Clock clock;

  /// The chosen moment; null means "Now".
  final DateTime? value;

  final ValueChanged<DateTime> onChanged;

  final String? errorText;

  @override
  State<DateTimeField> createState() => _DateTimeFieldState();
}

class _DateTimeFieldState extends State<DateTimeField> {
  static final _format = DateFormat.yMMMd().add_jm();
  var _pickedInFuture = false;

  Future<void> _pick() async {
    final now = widget.clock();
    final shown = (widget.value ?? now).toLocal();
    final date = await showDatePicker(
      context: context,
      initialDate: shown,
      firstDate: DateTime(1900),
      lastDate: DateTime(now.year, now.month, now.day),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(shown));
    if (time == null || !mounted) return;
    final picked = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    final isFuture = picked.isAfter(widget.clock());
    setState(() => _pickedInFuture = isFuture);
    if (!isFuture) widget.onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final value = widget.value;
    return InkWell(
      onTap: _pick,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'When',
          errorText: _pickedInFuture ? futureTimeError : widget.errorText,
        ),
        child: Text(value == null ? 'Now' : _format.format(value.toLocal())),
      ),
    );
  }
}
