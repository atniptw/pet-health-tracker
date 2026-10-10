import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/household.dart';
import '../../data/pet.dart';
import '../../data/symptom_log.dart';
import '../household/household_providers.dart';
import 'edit_log_screen.dart';
import 'occurred_at.dart';
import 'symptom_details_screen.dart';
import 'symptom_providers.dart';

/// Opens [pet]'s history for the signed-in user, [uid].
void openPetLogs(
  BuildContext context, {
  required Household household,
  required String uid,
  required Pet pet,
}) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (context) => PetLogsScreen(
        householdId: household.id,
        pet: pet,
        uid: uid,
        isAdmin: household.adminIds.contains(uid),
        hasOtherMembers: household.memberIds.length > 1,
      ),
    ),
  );
}

/// A pet's symptom logs. Tapping a log the user may change opens it for
/// editing.
class PetLogsScreen extends ConsumerWidget {
  const PetLogsScreen({
    required this.householdId,
    required this.pet,
    required this.uid,
    required this.isAdmin,
    required this.hasOtherMembers,
    super.key,
  });

  final String householdId;
  final Pet pet;

  /// The signed-in user.
  final String uid;

  /// Whether the signed-in user is a household admin, who can edit anyone's logs.
  final bool isAdmin;

  /// Whether anyone else is in the household. Logs show who logged them only
  /// when they could be someone else's.
  final bool hasOtherMembers;

  /// Members can edit their own logs, admins anyone's.
  bool _canEdit(SymptomLog log) => isAdmin || log.createdBy == uid;

  /// The form for an `other` log, or the catalog questions for any other.
  void _open(BuildContext context, SymptomLog log) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => log.symptom == SymptomLog.otherSymptom
            ? EditLogScreen(householdId: householdId, petId: pet.id, log: log)
            : SymptomDetailsScreen(
                householdId: householdId,
                petId: pet.id,
                petName: pet.name,
                log: log,
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = (householdId: householdId, petId: pet.id);
    final logsState = ref.watch(symptomLogsProvider(key));
    final catalog = ref.watch(symptomCatalogProvider).value;
    final names = ref.watch(memberNamesProvider(householdId)).value ?? const {};

    return Scaffold(
      appBar: AppBar(title: Text(pet.name)),
      body: logsState.when(
        data: (logs) => logs.isEmpty
            ? const Center(child: Text('Nothing logged yet'))
            : ListView.separated(
                itemCount: logs.length,
                separatorBuilder: (context, index) => Divider(
                  height: 1,
                  thickness: 1,
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
                itemBuilder: (context, index) {
                  final log = logs[index];
                  return _LogTile(
                    log: log,
                    title: log.title ?? catalog?.symptom(log.symptom)?.label ?? log.symptom,
                    loggedBy: hasOtherMembers || log.createdBy != uid ? names[log.createdBy] : null,
                    onTap: _canEdit(log) ? () => _open(context, log) : null,
                  );
                },
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
  const _LogTile({required this.log, required this.title, this.loggedBy, this.onTap});

  final SymptomLog log;

  /// The `other` title, or the catalog label.
  final String title;

  /// The name of who logged it, when shown.
  final String? loggedBy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final occurredAt = formatOccurredAt(context, log.occurredAt);
    final when = loggedBy == null ? occurredAt : '$occurredAt · $loggedBy';
    final notes = log.notes;
    return ListTile(
      title: Text(title),
      subtitle: Text(notes == null ? when : '$when\n$notes'),
      isThreeLine: notes != null,
      onTap: onTap,
    );
  }
}
