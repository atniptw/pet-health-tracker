import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_version.dart';
import '../../core/firebase_providers.dart';
import '../../data/household.dart';
import '../household/household_providers.dart';
import '../household/invite_screen.dart';
import '../pets/pet_form_screen.dart';
import '../pets/pet_list.dart';
import 'delete_account_screen.dart';
import 'members_screen.dart';
import 'rename_household_dialog.dart';
import 'transfer_ownership_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({required this.household, required this.uid, super.key});

  /// The household as it was when settings opened. Changes, like a rename,
  /// come from [myHouseholdsProvider].
  final Household household;

  /// The signed-in user. Only admins can add and edit pets.
  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final household = watchHousehold(ref, this.household, uid);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          ..._petTiles(context, household),
          const Divider(height: 1),
          ..._householdTiles(context, ref, household),
          ..._leavingTiles(context, ref, household),
          ..._accountTiles(context, ref),
        ],
      ),
    );
  }

  /// The household's pets, which only admins can add and edit.
  List<Widget> _petTiles(BuildContext context, Household household) {
    final isAdmin = household.adminIds.contains(uid);
    return [
      ListTile(
        title: Text('Pets', style: Theme.of(context).textTheme.titleSmall),
        trailing: isAdmin
            ? TextButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Add pet'),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (context) => PetFormScreen(householdId: household.id),
                  ),
                ),
              )
            : null,
      ),
      PetList(
        householdId: household.id,
        shrinkWrap: true,
        onTap: isAdmin
            ? (pet) => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) => PetFormScreen(householdId: household.id, pet: pet),
                ),
              )
            : null,
      ),
    ];
  }

  List<Widget> _householdTiles(BuildContext context, WidgetRef ref, Household household) {
    final isAdmin = household.adminIds.contains(uid);
    return [
      if (isAdmin)
        ListTile(
          leading: const Icon(Icons.edit_outlined),
          title: const Text('Household name'),
          subtitle: Text(household.name),
          onTap: () => _rename(context, ref, household),
        ),
      if (isAdmin)
        ListTile(
          leading: const Icon(Icons.person_add_outlined),
          title: const Text('Invite someone'),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (context) => InviteScreen(household: household, uid: uid),
            ),
          ),
        ),
      ListTile(
        leading: const Icon(Icons.group_outlined),
        title: const Text('Members'),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (context) => MembersScreen(household: household, uid: uid),
          ),
        ),
      ),
    ];
  }

  /// Transferring, leaving and deleting the household.
  List<Widget> _leavingTiles(BuildContext context, WidgetRef ref, Household household) {
    final isOwner = household.ownerId == uid;
    return [
      if (isOwner)
        ListTile(
          leading: const Icon(Icons.swap_horiz),
          title: const Text('Transfer ownership'),
          subtitle: household.memberIds.length > 1 ? null : const Text('Invite someone first'),
          enabled: household.memberIds.length > 1,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (context) => TransferOwnershipScreen(household: household, uid: uid),
            ),
          ),
        ),
      ListTile(
        leading: const Icon(Icons.exit_to_app),
        title: const Text('Leave household'),
        subtitle: isOwner ? const Text("The owner can't leave a household") : null,
        enabled: !isOwner,
        onTap: () => _leave(context, ref, household),
      ),
      if (isOwner)
        ListTile(
          leading: const Icon(Icons.delete_outline),
          title: const Text('Delete household'),
          onTap: () => _delete(context, ref, household),
        ),
    ];
  }

  List<Widget> _accountTiles(BuildContext context, WidgetRef ref) {
    return [
      ListTile(
        leading: const Icon(Icons.info_outline),
        title: const Text('Version'),
        trailing: Text(
          ref.watch(appVersionProvider).value ?? '',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ),
      ListTile(
        leading: const Icon(Icons.person_remove_outlined),
        title: const Text('Delete account'),
        onTap: () =>
            Navigator.of(context)
                .push(MaterialPageRoute<void>(builder: (context) => DeleteAccountScreen(uid: uid))),
      ),
      SafeArea(
        top: false,
        child: ListTile(
          leading: const Icon(Icons.logout),
          title: const Text('Sign out'),
          onTap: () async {
            // Pop back to the root so the auth gate's sign-in screen shows.
            Navigator.of(context).popUntil((route) => route.isFirst);
            await ref.read(authRepositoryProvider).signOut();
          },
        ),
      ),
    ];
  }

  Future<void> _rename(BuildContext context, WidgetRef ref, Household household) async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) => RenameHouseholdDialog(name: household.name),
    );
    if (name == null || name == household.name) return;
    // Like logging, renaming doesn't wait for the server. The new name shows
    // right away from the local write.
    unawaited(
      ref.read(householdRepositoryProvider).renameHousehold(householdId: household.id, name: name),
    );
  }

  Future<void> _leave(BuildContext context, WidgetRef ref, Household household) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Leave ${household.name}?'),
        content: const Text(
          "You'll lose access to its pets and logs. The symptoms you logged stay, "
          'and show "Former member" instead of your name. To come back, '
          "you'll need a new invite code.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Leave')),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    // Back to the root, which opens another household or the create and join
    // choice. Like logging, leaving doesn't wait for the server.
    Navigator.of(context).popUntil((route) => route.isFirst);
    unawaited(
      ref.read(householdRepositoryProvider).leaveHousehold(householdId: household.id, uid: uid),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, Household household) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${household.name}?'),
        content: const Text(
          'This deletes its pets and all their symptom logs, for everyone in it. '
          "It can't be undone.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final deleting = ref.read(householdRepositoryProvider).deleteHousehold(household.id);
    // Unlike other changes, deleting waits for the server, so with no
    // connection the owner is told instead of the delete waiting unseen.
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
                Expanded(child: Text('Deleting ${household.name}…')),
              ],
            ),
          ),
        ),
      ),
    );
    try {
      await deleting;
      // Back to the root, which opens another household or the create and
      // join choice.
      navigator.popUntil((route) => route.isFirst);
    } catch (_) {
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text("Couldn't delete ${household.name}. Check your connection and try again."),
        ),
      );
    }
  }
}
