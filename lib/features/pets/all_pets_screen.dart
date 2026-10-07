import 'package:flutter/material.dart';

import '../../data/household.dart';
import '../symptoms/pet_logs_screen.dart';
import 'pet_form_screen.dart';
import 'pet_list.dart';

/// Every pet in the household. Tapping one opens its history; admins can add
/// a pet.
class AllPetsScreen extends StatelessWidget {
  const AllPetsScreen({required this.household, required this.uid, super.key});

  final Household household;

  /// The signed-in user.
  final String uid;

  @override
  Widget build(BuildContext context) {
    final isAdmin = household.adminIds.contains(uid);
    return Scaffold(
      appBar: AppBar(
        title: const Text('All pets'),
        actions: [
          if (isAdmin)
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Add pet',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) => PetFormScreen(householdId: household.id),
                ),
              ),
            ),
        ],
      ),
      body: PetList(
        householdId: household.id,
        onTap: (pet) => openPetLogs(context, household: household, uid: uid, pet: pet),
      ),
    );
  }
}
