import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/pet.dart';
import 'pet_providers.dart';

class PetList extends ConsumerWidget {
  const PetList({required this.householdId, this.onTap, super.key});

  final String householdId;

  /// Called when a pet is tapped. Pets aren't tappable when null.
  final ValueChanged<Pet>? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final petsState = ref.watch(petsProvider(householdId));

    return petsState.when(
      data: (pets) => pets.isEmpty
          ? const Center(child: Text('No pets yet'))
          : ListView(
              children: [
                for (final pet in pets)
                  _PetTile(pet: pet, onTap: onTap == null ? null : () => onTap!(pet)),
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

/// "Dog · Beagle", or the species alone when the breed isn't set.
String describePet(Pet pet) {
  final breed = pet.breed;
  return breed == null ? pet.species.label : '${pet.species.label} · $breed';
}

class _PetTile extends StatelessWidget {
  const _PetTile({required this.pet, required this.onTap});

  final Pet pet;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(child: Text(pet.name.characters.first.toUpperCase())),
      title: Text(pet.name),
      subtitle: Text(describePet(pet)),
      onTap: onTap,
    );
  }
}
