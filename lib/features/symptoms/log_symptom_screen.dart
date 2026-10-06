import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/firebase_providers.dart';
import '../../data/symptom_log.dart';
import 'occurred_at.dart';

/// Logs a symptom for a pet: a title, when it happened, and optional notes.
/// Edits [log] when one is given.
class LogSymptomScreen extends ConsumerStatefulWidget {
  const LogSymptomScreen({
    required this.householdId,
    required this.petId,
    required this.petName,
    required this.uid,
    this.log,
    super.key,
  });

  final String householdId;
  final String petId;
  final String petName;

  /// The signed-in user, recorded as a new log's author.
  final String uid;

  /// An [SymptomLog.otherSymptom] log to edit.
  final SymptomLog? log;

  @override
  ConsumerState<LogSymptomScreen> createState() => _LogSymptomScreenState();
}

class _LogSymptomScreenState extends ConsumerState<LogSymptomScreen> {
  late final _titleController = TextEditingController(text: widget.log?.title);
  late final _notesController = TextEditingController(text: widget.log?.notes);

  /// When it happened. Null means now, taken at the moment of saving.
  late DateTime? _occurredAt = widget.log?.occurredAt;
  bool _showMissing = false;

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickOccurredAt() async {
    final now = DateTime.now();
    final initial = _occurredAt ?? now;
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 50),
      lastDate: now,
      helpText: 'When did it happen?',
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) return;
    setState(() => _occurredAt = DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }

  void _save() {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() => _showMissing = true);
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    final repository = ref.read(symptomLogRepositoryProvider);
    final occurredAt = _occurredAt ?? DateTime.now();
    final notes = _notesController.text.trim();
    final log = widget.log;
    final write = log == null
        ? repository.addOtherLog(
            householdId: widget.householdId,
            petId: widget.petId,
            createdBy: widget.uid,
            title: title,
            occurredAt: occurredAt,
            notes: notes,
          )
        : repository.updateOtherLog(
            householdId: widget.householdId,
            petId: widget.petId,
            logId: log.id,
            title: title,
            occurredAt: occurredAt,
            notes: notes,
          );
    // Not awaited: Firestore completes the write only once the server has it,
    // and logging has to work without signal. The local cache shows the log
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
    final occurredAt = _occurredAt;
    final editing = widget.log != null;

    return Scaffold(
      appBar: AppBar(title: Text(editing ? 'Edit log' : 'Log for ${widget.petName}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _titleController,
            autofocus: !editing,
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
            subtitle: Text(occurredAt == null ? 'Now' : formatOccurredAt(context, occurredAt)),
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
