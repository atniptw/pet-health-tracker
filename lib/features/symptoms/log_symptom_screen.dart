import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/firebase_providers.dart';
import 'occurred_at.dart';

/// Logs a symptom for a pet: a title, when it happened, and optional notes.
class LogSymptomScreen extends ConsumerStatefulWidget {
  const LogSymptomScreen({
    required this.householdId,
    required this.petId,
    required this.petName,
    required this.uid,
    super.key,
  });

  final String householdId;
  final String petId;
  final String petName;

  /// The signed-in user, recorded as the log's author.
  final String uid;

  @override
  ConsumerState<LogSymptomScreen> createState() => _LogSymptomScreenState();
}

class _LogSymptomScreenState extends ConsumerState<LogSymptomScreen> {
  final _titleController = TextEditingController();
  final _notesController = TextEditingController();

  /// When it happened. Null means now, taken at the moment of saving.
  DateTime? _occurredAt;
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
    // Not awaited: Firestore completes the write only once the server has it,
    // and logging has to work without signal. The local cache shows the log
    // straight away.
    unawaited(
      ref
          .read(symptomLogRepositoryProvider)
          .addOtherLog(
            householdId: widget.householdId,
            petId: widget.petId,
            createdBy: widget.uid,
            title: title,
            occurredAt: _occurredAt ?? DateTime.now(),
            notes: _notesController.text.trim(),
          )
          .catchError((Object e) {
            messenger.showSnackBar(SnackBar(content: Text("Couldn't save the log: $e")));
          }),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final occurredAt = _occurredAt;

    return Scaffold(
      appBar: AppBar(title: Text('Log for ${widget.petName}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _titleController,
            autofocus: true,
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
