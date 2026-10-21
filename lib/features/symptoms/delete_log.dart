import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/symptom_log_repository.dart';

/// Asks whether to delete the log, deletes it if so, and returns whether it
/// did. Deleting isn't awaited, so it works without signal; the local cache
/// drops the log straight away.
Future<bool> confirmDeleteLog(
  BuildContext context,
  SymptomLogRepository repository, {
  required String householdId,
  required String petId,
  required String logId,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Delete this log?'),
      content: const Text("It's deleted for everyone in the household. It can't be undone."),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Delete')),
      ],
    ),
  );
  if (confirmed != true) return false;
  unawaited(
    repository.deleteLog(householdId: householdId, petId: petId, logId: logId).catchError((
      Object e,
    ) {
      messenger.showSnackBar(SnackBar(content: Text("Couldn't delete the log: $e")));
    }),
  );
  return true;
}
