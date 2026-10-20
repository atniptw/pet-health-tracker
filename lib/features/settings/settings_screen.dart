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

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({required this.household, required this.uid, super.key});

  /// The household as it was when settings opened. Changes, like a rename,
  /// come from [myHouseholdsProvider].
  final Household household;

  /// The signed-in user. Only admins can add and edit pets.
  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final household = _current(ref);
    final isAdmin = household.adminIds.contains(uid);
    final isOwner = household.ownerId == uid;
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
            leading: const Icon(Icons.exit_to_app),
            title: const Text('Leave household'),
            subtitle: isOwner ? const Text("The owner can't leave a household") : null,
            enabled: !isOwner,
            onTap: () => _leave(context, ref, household),
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

  Household _current(WidgetRef ref) {
    final households = ref.watch(myHouseholdsProvider(uid)).value ?? const <Household>[];
    return households.where((h) => h.id == household.id).firstOrNull ?? household;
  }

  Future<void> _rename(BuildContext context, WidgetRef ref, Household household) async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) => _RenameDialog(name: household.name),
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
}

/// Asks for the household's new name, and pops with it trimmed.
class _RenameDialog extends StatefulWidget {
  const _RenameDialog({required this.name});

  final String name;

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final _controller = TextEditingController(text: widget.name);
  bool _showMissing = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final name = _controller.text.trim();
    if (name.isEmpty) {
      setState(() => _showMissing = true);
      return;
    }
    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Household name'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: 100,
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(
          labelText: 'Name',
          errorText: _showMissing && _controller.text.trim().isEmpty ? 'Enter a name' : null,
        ),
        onChanged: (_) => setState(() {}),
        onSubmitted: (_) => _save(),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        TextButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}
