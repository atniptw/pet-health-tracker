import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/pet.dart';
import 'pet_providers.dart';

class PetList extends ConsumerWidget {
  const PetList({
    required this.householdId,
    this.onTap,
    this.trailing,
    this.archived = false,
    this.shrinkWrap = false,
    super.key,
  });

  final String householdId;

  /// Lists the household's archived pets instead of the others.
  final bool archived;

  /// Lays the pets out at their full height inside another scrolling list,
  /// instead of scrolling on their own.
  final bool shrinkWrap;

  /// Called when a pet is tapped. Pets aren't tappable when null.
  final ValueChanged<Pet>? onTap;

  /// What each pet's row shows at its end, if anything.
  final Widget Function(Pet pet)? trailing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = archived ? archivedPetsProvider(householdId) : petsProvider(householdId);
    final petsState = ref.watch(provider);

    return petsState.when(
      data: (pets) => pets.isEmpty
          ? Center(child: Text(archived ? 'No archived pets' : 'No pets yet'))
          : ListView(
              shrinkWrap: shrinkWrap,
              physics: shrinkWrap ? const NeverScrollableScrollPhysics() : null,
              children: [
                for (final pet in pets)
                  _PetTile(
                    pet: pet,
                    onTap: onTap == null ? null : () => onTap!(pet),
                    trailing: trailing?.call(pet),
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
            FilledButton(onPressed: () => ref.invalidate(provider), child: const Text('Retry')),
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
  const _PetTile({required this.pet, required this.onTap, required this.trailing});

  final Pet pet;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(child: Text(pet.name.characters.first.toUpperCase())),
      title: Text(pet.name),
      subtitle: Text(describePet(pet)),
      trailing: trailing,
      onTap: onTap,
    );
  }
}
