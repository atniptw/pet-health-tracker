import 'package:flutter/material.dart';

import '../../domain/pet.dart';
import 'pet_form.dart';

/// Adds a pet, or edits [pet] keeping its id so its events stay with it,
/// and closes once saved.
class PetFormScreen extends StatelessWidget {
  const PetFormScreen({super.key, this.pet});

  /// The pet to edit, or null to add one.
  final Pet? pet;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(pet == null ? 'Add pet' : 'Edit pet')),
      body: PetForm(pet: pet, onSaved: () => Navigator.of(context).pop()),
    );
  }
}
