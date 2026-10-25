import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/firebase_providers.dart';
import '../../data/household.dart';
import '../household/household_members.dart';
import '../household/household_providers.dart';
import 'dialogs.dart';

/// Everyone in the household, by name, with who is the owner or an admin
/// and which one is [uid]. Admins can remove members who aren't admins, and
/// the owner anyone else.
class MembersScreen extends ConsumerWidget {
  const MembersScreen({required this.household, required this.uid, super.key});

  final Household household;
  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final household = watchHousehold(ref, this.household, uid);
    final names = ref.watch(memberNamesProvider(household.id)).value ?? const {};
    final members = sortedMembers(household, names);
    // Someone removed while this is open keeps the last household they saw,
    // so their menus go once they're out of it.
    final stillIn =
        ref.watch(myHouseholdsProvider(uid)).value?.any((h) => h.id == household.id) ?? false;
    return Scaffold(
      appBar: AppBar(title: const Text('Members')),
      body: ListView(
        children: [
          for (final member in members)
            // Keyed by person, so a menu left open on someone who leaves goes
            // with their row instead of passing to whoever moves into its place.
            ListTile(
              key: ValueKey(member.uid),
              title: Text(member.name ?? noNameYet),
              subtitle: _labels(household, member.uid),
              trailing: stillIn && _canRemove(household, member.uid)
                  ? PopupMenuButton<_Action>(
                      tooltip: 'Options for ${member.name ?? noNameYet}',
                      onSelected: (action) => switch (action) {
                        _Action.remove => _remove(context, ref, household, member),
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(value: _Action.remove, child: Text('Remove from household')),
                      ],
                    )
                  : null,
            ),
        ],
      ),
    );
  }

  Widget? _labels(Household household, String memberId) {
    final labels = [
      if (memberId == household.ownerId)
        'Owner'
      else if (household.adminIds.contains(memberId))
        'Admin',
      if (memberId == uid) 'You',
    ];
    return labels.isEmpty ? null : Text(labels.join(' · '));
  }

  /// Whether [uid] may remove [memberId], matching the security rules.
  bool _canRemove(Household household, String memberId) {
    if (memberId == uid || memberId == household.ownerId) return false;
    if (household.adminIds.contains(memberId)) return household.ownerId == uid;
    return household.adminIds.contains(uid);
  }

  Future<void> _remove(
    BuildContext context,
    WidgetRef ref,
    Household household,
    HouseholdMember member,
  ) async {
    final name = member.name ?? 'this member';
    final confirmed = await askToConfirm(
      context,
      title: 'Remove $name?',
      message:
          "They'll lose access to its pets and logs. The symptoms they logged stay, "
          'and show "Former member" instead of their name. The current invite code '
          'stops working, so make a new one to invite anyone else.',
      action: 'Remove',
    );
    if (!confirmed || !context.mounted) return;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final removing = ref
        .read(householdRepositoryProvider)
        .removeMember(householdId: household.id, uid: member.uid);
    // Like deleting a household, removing waits for the server, so with no
    // connection the admin is told.
    showProgressDialog(context, 'Removing $name…');
    try {
      await removing;
      navigator.pop();
    } catch (_) {
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(content: Text("Couldn't remove $name. Check your connection and try again.")),
      );
    }
  }
}

/// What the viewer can do to someone from their row's menu.
enum _Action { remove }
