import 'package:flutter/material.dart';

import 'pet_form.dart';

/// Asks for the first pet with the pet form. Once saved, "Save" stays
/// disabled and the screen stays put: the app's start screen choice, which
/// follows the active pets, replaces it.
class FirstPetScreen extends StatelessWidget {
  const FirstPetScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add your first pet')),
      body: const PetForm(),
    );
  }
}
