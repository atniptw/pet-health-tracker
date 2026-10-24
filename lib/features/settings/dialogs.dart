import 'dart:async';

import 'package:flutter/material.dart';

/// Shows [message] with a spinner until the caller pops it. It can't be
/// dismissed, so the change it waits for can't be started again meanwhile.
void showProgressDialog(BuildContext context, String message) {
  unawaited(
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 24),
              Expanded(child: Text(message)),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Asks [title] with [message], and whether the user picked [action] rather
/// than Cancel.
Future<bool> askToConfirm(
  BuildContext context, {
  required String title,
  required String message,
  required String action,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.of(context).pop(true), child: Text(action)),
      ],
    ),
  );
  return confirmed ?? false;
}
