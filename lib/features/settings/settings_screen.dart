import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/firebase_providers.dart';
import '../../data/household.dart';
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
}
