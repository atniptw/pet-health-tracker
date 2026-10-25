import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/firebase_providers.dart';
import '../../data/household.dart';
import '../household/household_members.dart';
import '../household/household_providers.dart';
import 'dialogs.dart';

/// Everyone in the household, by name, with who is the owner or an admin
/// and which one is [uid]. Admins can remove members who aren't admins, and
/// the owner anyone else; only the owner changes roles.
class MembersScreen extends ConsumerWidget {
  const MembersScreen({required this.household, required this.uid, super.key});

  final Household household;
  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final household = watchHousehold(ref, this.household, uid);
    final names = ref.watch(memberNamesProvider(household.id)).value ?? const {};
    final members = sortedMembers(household, names);
    final stillIn = watchStillIn(ref, household.id, uid);
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
              trailing: stillIn ? _menu(context, ref, household, member) : null,
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

  /// [member]'s menu of what [uid] can do to them, or null if there's nothing.
  Widget? _menu(BuildContext context, WidgetRef ref, Household household, HouseholdMember member) {
    final actions = [
      if (household.ownerId == uid && member.uid != uid)
        household.adminIds.contains(member.uid) ? _Action.removeAdmin : _Action.makeAdmin,
      if (_canRemove(household, member.uid)) _Action.remove,
    ];
    if (actions.isEmpty) return null;
    return PopupMenuButton<_Action>(
      tooltip: 'Options for ${member.name ?? noNameYet}',
      onSelected: (action) => switch (action) {
        _Action.makeAdmin => _changeRole(context, ref, household, member, makeAdmin: true),
        _Action.removeAdmin => _changeRole(context, ref, household, member, makeAdmin: false),
        _Action.remove => _remove(context, ref, household, member),
      },
      itemBuilder: (context) => [
        for (final action in actions) PopupMenuItem(value: action, child: Text(action.label)),
      ],
    );
  }

  /// Whether [uid] may remove [memberId], matching the security rules.
  bool _canRemove(Household household, String memberId) {
    if (memberId == uid || memberId == household.ownerId) return false;
    if (household.adminIds.contains(memberId)) return household.ownerId == uid;
    return household.adminIds.contains(uid);
  }

  /// Makes [member] an admin, or takes admin away, after confirming. Only the
  /// owner sees these actions, matching the security rules.
  Future<void> _changeRole(
    BuildContext context,
    WidgetRef ref,
    Household household,
    HouseholdMember member, {
    required bool makeAdmin,
  }) async {
    final name = member.name ?? 'this member';
    final confirmed = await askToConfirm(
      context,
      title: makeAdmin ? 'Make $name an admin?' : 'Remove $name as admin?',
      message: makeAdmin
          ? "They'll be able to add and edit pets, edit and delete everyone's logs, "
                "invite people, rename the household and remove members who aren't admins."
          : "They'll stay in the household as a member.",
      action: makeAdmin ? 'Make admin' : 'Remove as admin',
    );
    if (!confirmed || !context.mounted) return;
    final households = ref.read(householdRepositoryProvider);
    // Like transferring ownership, changing a role doesn't wait for the server.
    // The new role shows right away from the local write.
    unawaited(
      makeAdmin
          ? households.makeAdmin(householdId: household.id, uid: member.uid)
          : households.removeAdmin(householdId: household.id, uid: member.uid),
    );
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
enum _Action {
  makeAdmin('Make admin'),
  removeAdmin('Remove as admin'),
  remove('Remove from household');

  const _Action(this.label);

  final String label;
}
