import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/repositories.dart';
import 'archived_pets_screen.dart';
import 'pet_form_screen.dart';
import 'pet_name_list.dart';

/// The active pets by name, each opening its history, "Add pet", which
/// opens the pet form, and "Archived pets".
///
/// A failed read is reported to the app's error handler and keeps the last
/// list read; before any has been read, it shows [loadFailed].
class PetsScreen extends StatelessWidget {
  const PetsScreen({super.key, required this.clock});

  /// Passed to the pet history the screen opens.
  final Clock clock;

  /// Shown when the pets can't be read before any have been.
  static const loadFailed = "Your pets couldn't be loaded. Close the app and open it again.";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pets'),
        actions: [
          TextButton(
            onPressed: () => unawaited(
              Navigator.push(
                context,
                MaterialPageRoute<void>(builder: (_) => const PetFormScreen()),
              ),
            ),
            child: const Text('Add pet'),
          ),
        ],
      ),
      body: PetNameList(
        watch: (pets) => pets.watchActive(),
        clock: clock,
        what: 'Reading the pets',
        loadFailed: loadFailed,
      ),
      persistentFooterButtons: [
        TextButton(
          onPressed: () => ArchivedPetsScreen.open(context, clock),
          child: const Text('Archived pets'),
        ),
      ],
    );
  }
}
