import 'package:flutter/material.dart';

/// Asks for the household's new name, and pops with it trimmed.
class RenameHouseholdDialog extends StatefulWidget {
  const RenameHouseholdDialog({required this.name, super.key});

  final String name;

  @override
  State<RenameHouseholdDialog> createState() => _RenameHouseholdDialogState();
}

class _RenameHouseholdDialogState extends State<RenameHouseholdDialog> {
  late final _controller = TextEditingController(text: widget.name);
  bool _showMissing = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final name = _controller.text.trim();
    if (name.isEmpty) {
      setState(() => _showMissing = true);
      return;
    }
    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Household name'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: 100,
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(
          labelText: 'Name',
          errorText: _showMissing && _controller.text.trim().isEmpty ? 'Enter a name' : null,
        ),
        onChanged: (_) => setState(() {}),
        onSubmitted: (_) => _save(),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        TextButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}
