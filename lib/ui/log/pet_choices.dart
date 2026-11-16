import 'package:flutter/material.dart';

import '../../domain/pet.dart';

/// A chip per pet in [pets], with the pet whose id is [pickedId] highlighted,
/// and "Who is this for?" above them while none of them is picked (FR-007).
/// Tapping another pet reports its id; tapping the picked pet keeps it.
class PetChoices extends StatelessWidget {
  const PetChoices({super.key, required this.pets, required this.pickedId, required this.onPicked});

  /// The active pets to choose from.
  final List<Pet> pets;

  /// The picked pet's id, or null when none is picked.
  final String? pickedId;

  final ValueChanged<String> onPicked;

  @override
  Widget build(BuildContext context) {
    final nonePicked = !pets.any((pet) => pet.id == pickedId);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (nonePicked) Text('Who is this for?', style: Theme.of(context).textTheme.titleSmall),
        Wrap(
          spacing: 8,
          children: [
            for (final pet in pets)
              ChoiceChip(
                label: Text(pet.name),
                selected: pet.id == pickedId,
                onSelected: (selected) {
                  if (selected) onPicked(pet.id);
                },
              ),
          ],
        ),
      ],
    );
  }
}
