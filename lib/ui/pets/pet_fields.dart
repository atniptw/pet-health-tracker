import 'package:flutter/material.dart';

import '../../domain/names.dart';
import '../../domain/pet.dart';

/// The pet's name, up to [maxNameLength] characters.
class PetNameField extends StatelessWidget {
  const PetNameField({super.key, required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    maxLength: maxNameLength,
    textCapitalization: TextCapitalization.words,
    decoration: const InputDecoration(labelText: 'Name'),
  );
}

/// One choice per [Species], with [selected] picked.
class SpeciesChoices extends StatelessWidget {
  const SpeciesChoices({super.key, required this.selected, required this.onSelected});

  final Species selected;
  final ValueChanged<Species> onSelected;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    children: [
      for (final species in Species.values)
        ChoiceChip(
          label: Text(species.label),
          selected: species == selected,
          onSelected: (_) => onSelected(species),
        ),
    ],
  );
}
