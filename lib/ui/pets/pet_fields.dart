import 'package:flutter/material.dart';

import '../../domain/names.dart';
import '../../domain/pet.dart';
import '../common/value_choices.dart';

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
  Widget build(BuildContext context) => ValueChoices(
    values: Species.values,
    label: (species) => species.label,
    picked: selected,
    onPicked: onSelected,
  );
}
