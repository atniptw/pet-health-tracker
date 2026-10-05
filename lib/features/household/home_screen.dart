import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/firebase_providers.dart';
import '../../data/household.dart';
import '../pets/pet_form_screen.dart';
import '../pets/pet_list.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({required this.household, required this.uid, super.key});

  final Household household;

  /// The signed-in user. Only admins can add and edit pets.
  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = household.adminIds.contains(uid);
    return Scaffold(
      appBar: AppBar(
        title: Text(household.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: () => ref.read(authRepositoryProvider).signOut(),
          ),
        ],
      ),
      body: PetList(householdId: household.id, canEdit: isAdmin),
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              icon: const Icon(Icons.add),
              label: const Text('Add pet'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) => PetFormScreen(householdId: household.id),
                ),
              ),
            )
          : null,
    );
  }
}
