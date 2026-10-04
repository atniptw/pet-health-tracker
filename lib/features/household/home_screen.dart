import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/firebase_providers.dart';
import '../../data/household.dart';
import '../pets/add_pet_screen.dart';
import '../pets/pet_list.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({required this.household, required this.uid, super.key});

  final Household household;

  /// The signed-in user. Only admins can add pets.
  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
      body: PetList(householdId: household.id),
      floatingActionButton: household.adminIds.contains(uid)
          ? FloatingActionButton.extended(
              icon: const Icon(Icons.add),
              label: const Text('Add pet'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) => AddPetScreen(householdId: household.id),
                ),
              ),
            )
          : null,
    );
  }
}
