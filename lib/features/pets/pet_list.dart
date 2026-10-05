import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/pet.dart';
import 'pet_form_screen.dart';
import 'pet_providers.dart';

class PetList extends ConsumerWidget {
  const PetList({required this.householdId, required this.canEdit, super.key});

  final String householdId;

  /// Whether tapping a pet opens it for editing. Only admins can edit pets.
  final bool canEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final petsState = ref.watch(petsProvider(householdId));

    return petsState.when(
      data: (pets) => pets.isEmpty
          ? const Center(child: Text('No pets yet'))
          : ListView(
              children: [
                for (final pet in pets)
                  _PetTile(
                    pet: pet,
                    onTap: canEdit
                        ? () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (context) =>
                                  PetFormScreen(householdId: householdId, pet: pet),
                            ),
                          )
                        : null,
                  ),
              ],
            ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$error'),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => ref.invalidate(petsProvider(householdId)),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PetTile extends StatelessWidget {
  const _PetTile({required this.pet, required this.onTap});

  final Pet pet;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final breed = pet.breed;
    return ListTile(
      leading: CircleAvatar(child: Text(pet.name.characters.first.toUpperCase())),
      title: Text(pet.name),
      subtitle: Text(breed == null ? pet.species.label : '${pet.species.label} · $breed'),
      onTap: onTap,
    );
  }
}
