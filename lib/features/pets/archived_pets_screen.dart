import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/firebase_providers.dart';
import '../../data/household.dart';
import '../household/household_providers.dart';
import '../symptoms/pet_logs_screen.dart';
import 'pet_list.dart';

/// The household's archived pets. Tapping one opens its history; admins can
/// unarchive one, bringing it back to the household's pets.
class ArchivedPetsScreen extends ConsumerWidget {
  const ArchivedPetsScreen({required this.household, required this.uid, super.key});

  final Household household;

  /// The signed-in user.
  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final household = watchHousehold(ref, this.household, uid);
    final stillIn = watchStillIn(ref, household.id, uid);
    final canUnarchive = stillIn && household.adminIds.contains(uid);
    return Scaffold(
      appBar: AppBar(title: const Text('Archived pets')),
      body: PetList(
        householdId: household.id,
        archived: true,
        onTap: (pet) => openPetLogs(context, household: household, uid: uid, pet: pet),
        trailing: canUnarchive
            ? (pet) => TextButton(
                // Like renaming, unarchiving doesn't wait for the server. The
                // pet moves back right away from the local write.
                onPressed: () => unawaited(
                  ref
                      .read(petRepositoryProvider)
                      .unarchivePet(householdId: household.id, petId: pet.id),
                ),
                child: const Text('Unarchive'),
              )
            : null,
      ),
    );
  }
}
