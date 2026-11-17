import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/repositories.dart';
import '../../domain/event_type.dart';
import '../../domain/names.dart';
import '../../domain/pet.dart';
import 'log_sheet.dart';

/// Asks "What happened?" for an event type in the caregiver's own words.
/// Closes with the typed name, trimmed and with inner runs of spaces
/// collapsed, once "Continue" is tapped; "Continue" is disabled while the
/// name is empty or only spaces (D-014).
class SomethingElseSheet extends StatefulWidget {
  const SomethingElseSheet({super.key});

  @override
  State<SomethingElseSheet> createState() => _SomethingElseSheetState();
}

class _SomethingElseSheetState extends State<SomethingElseSheet> {
  final _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  bool get _hasName => _name.text.trim().isNotEmpty;

  void _continue() {
    if (_hasName) Navigator.pop(context, validTypeName(_name.text));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _name,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'What happened?'),
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.done,
              inputFormatters: [LengthLimitingTextInputFormatter(maxNameLength)],
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _continue(),
            ),
            const SizedBox(height: 24),
            FilledButton(onPressed: _hasName ? _continue : null, child: const Text('Continue')),
          ],
        ),
      ),
    );
  }
}

/// The log sheet for [name] typed under "What happened?": the type it
/// matches in [types] (research §7), or a new type of that name.
///
/// A matched custom type that was removed is logged by name, so saving
/// un-removes it and offers it again (FR-004).
LogSheet logSheetFor(
  String name,
  EventTypeRepository types, {
  required List<Pet> pets,
  required String? pickedPetId,
  required Clock clock,
}) {
  final EventType? type = types.match(name);
  if (type == null || type.removed) {
    return LogSheet.forNewName(
      type?.name ?? name,
      pets: pets,
      pickedPetId: pickedPetId,
      clock: clock,
    );
  }
  return LogSheet.forType(type, pets: pets, pickedPetId: pickedPetId, clock: clock);
}
