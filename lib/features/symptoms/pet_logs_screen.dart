import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/pet.dart';
import '../../data/symptom_log.dart';
import 'log_symptom_screen.dart';
import 'occurred_at.dart';
import 'symptom_providers.dart';

/// A pet's symptom logs, with a button to log a new one.
class PetLogsScreen extends ConsumerWidget {
  const PetLogsScreen({required this.householdId, required this.pet, required this.uid, super.key});

  final String householdId;
  final Pet pet;

  /// The signed-in user.
  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = (householdId: householdId, petId: pet.id);
    final logsState = ref.watch(symptomLogsProvider(key));

    return Scaffold(
      appBar: AppBar(title: Text(pet.name)),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Log symptom'),
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (context) => LogSymptomScreen(
              householdId: householdId,
              petId: pet.id,
              petName: pet.name,
              uid: uid,
            ),
          ),
        ),
      ),
      body: logsState.when(
        data: (logs) => logs.isEmpty
            ? const Center(child: Text('Nothing logged yet'))
            : ListView(
                // Room for the floating button over the last entry.
                padding: const EdgeInsets.only(bottom: 88),
                children: [for (final log in logs) _LogTile(log: log)],
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$error'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => ref.invalidate(symptomLogsProvider(key)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LogTile extends StatelessWidget {
  const _LogTile({required this.log});

  final SymptomLog log;

  @override
  Widget build(BuildContext context) {
    final when = formatOccurredAt(context, log.occurredAt);
    final notes = log.notes;
    return ListTile(
      title: Text(log.title ?? log.symptom),
      subtitle: Text(notes == null ? when : '$when\n$notes'),
      isThreeLine: notes != null,
    );
  }
}
