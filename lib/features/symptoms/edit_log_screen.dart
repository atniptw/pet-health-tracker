import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/firebase_providers.dart';
import '../../data/symptom_log.dart';
import 'occurred_at.dart';

/// Edits an `other` log: its title, when it happened, and its notes.
class EditLogScreen extends ConsumerStatefulWidget {
  const EditLogScreen({
    required this.householdId,
    required this.petId,
    required this.log,
    super.key,
  });

  final String householdId;
  final String petId;

  /// An [SymptomLog.otherSymptom] log.
  final SymptomLog log;

  @override
  ConsumerState<EditLogScreen> createState() => _EditLogScreenState();
}

class _EditLogScreenState extends ConsumerState<EditLogScreen> {
  late final _titleController = TextEditingController(text: widget.log.title);
  late final _notesController = TextEditingController(text: widget.log.notes);
  late DateTime _occurredAt = widget.log.occurredAt;
  bool _showMissing = false;

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickOccurredAt() async {
    final occurredAt = await pickOccurredAt(context, _occurredAt);
    if (occurredAt != null) setState(() => _occurredAt = occurredAt);
  }

  void _save() {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() => _showMissing = true);
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    final write = ref
        .read(symptomLogRepositoryProvider)
        .updateOtherLog(
          householdId: widget.householdId,
          petId: widget.petId,
          logId: widget.log.id,
          title: title,
          occurredAt: _occurredAt,
          notes: _notesController.text.trim(),
        );
    // Not awaited: Firestore completes the write only once the server has it,
    // and editing has to work without signal. The local cache shows the change
    // straight away.
    unawaited(
      write.catchError((Object e) {
        messenger.showSnackBar(SnackBar(content: Text("Couldn't save the log: $e")));
      }),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit log')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _titleController,
            maxLength: 100,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: 'Title',
              errorText: _showMissing && _titleController.text.trim().isEmpty
                  ? 'Enter a title'
                  : null,
            ),
            onChanged: (_) => setState(() {}),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('When'),
            subtitle: Text(formatOccurredAt(context, _occurredAt)),
            trailing: const Icon(Icons.schedule),
            onTap: _pickOccurredAt,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _notesController,
            maxLength: 2000,
            minLines: 3,
            maxLines: null,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Notes (optional)'),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: _save, child: const Text('Save')),
        ],
      ),
    );
  }
}
