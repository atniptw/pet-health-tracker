import 'package:flutter/material.dart';

import '../../domain/pet.dart';
import '../app_scope.dart';
import 'pet_fields.dart';

/// The pet's name and species fields and "Save", which adds a pet, or
/// updates [pet] keeping its id so its events stay with it.
///
/// "Save" is enabled while the trimmed name isn't empty and no save is in
/// flight. Once a save succeeds it stays disabled and [onSaved] runs.
class PetForm extends StatefulWidget {
  const PetForm({super.key, this.pet, this.onSaved});

  /// The pet to edit, or null to add one.
  final Pet? pet;

  /// Runs after a save succeeds, while the form is still mounted.
  final VoidCallback? onSaved;

  @override
  State<PetForm> createState() => _PetFormState();
}

class _PetFormState extends State<PetForm> {
  late final _name = TextEditingController(text: widget.pet?.name);
  late var _species = widget.pet?.species ?? Species.dog;
  var _saving = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final pets = AppScope.of(context).pets;
    final pet = widget.pet;
    try {
      if (pet == null) {
        await pets.add(name: _name.text, species: _species);
      } else {
        await pets.update(pet.id, name: _name.text, species: _species);
      }
    } catch (_, stack) {
      // Save works again. The app's error handler gets an error without the
      // write's own message, which can hold the pet's name.
      if (mounted) setState(() => _saving = false);
      Error.throwWithStackTrace(StateError('Saving the pet failed'), stack);
    }
    if (mounted) widget.onSaved?.call();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        PetNameField(controller: _name),
        const SizedBox(height: 8),
        SpeciesChoices(
          selected: _species,
          onSelected: (species) => setState(() => _species = species),
        ),
        const SizedBox(height: 24),
        ListenableBuilder(
          listenable: _name,
          builder: (context, _) => FilledButton(
            onPressed: _name.text.trim().isEmpty || _saving ? null : _save,
            child: const Text('Save'),
          ),
        ),
      ],
    );
  }
}
