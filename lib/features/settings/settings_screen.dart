import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_version.dart';
import '../../core/firebase_providers.dart';
import '../../data/household.dart';
import '../household/invite_screen.dart';
import '../pets/pet_form_screen.dart';
import '../pets/pet_list.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({required this.household, required this.uid, super.key});

  final Household household;

  /// The signed-in user. Only admins can add and edit pets.
  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = household.adminIds.contains(uid);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
          Expanded(
            child: PetList(
              householdId: household.id,
              onTap: isAdmin
                  ? (pet) => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (context) => PetFormScreen(householdId: household.id, pet: pet),
                      ),
                    )
                  : null,
            ),
          ),
          const Divider(height: 1),
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
            leading: const Icon(Icons.exit_to_app),
            title: const Text('Leave household'),
            subtitle: isAdmin ? const Text("Admins can't leave a household") : null,
            enabled: !isAdmin,
            onTap: () => _leave(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Version'),
            trailing: Text(
              ref.watch(appVersionProvider).value ?? '',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
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
        ],
      ),
    );
  }

  Future<void> _leave(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Leave ${household.name}?'),
        content: const Text(
          "You'll lose access to its pets and logs. The symptoms you logged stay, "
          "with your name. To come back, you'll need a new invite code.",
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
}
