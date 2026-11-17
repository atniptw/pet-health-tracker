import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/repositories.dart';
import 'pet_name_list.dart';

/// The archived pets by name, each opening its history, where it can be
/// restored (FR-015); with none, [empty].
///
/// A failed read is reported to the app's error handler and keeps the last
/// list read; before any has been read, it shows [loadFailed].
class ArchivedPetsScreen extends StatelessWidget {
  const ArchivedPetsScreen({super.key, required this.clock});

  /// Passed to the pet history the screen opens.
  final Clock clock;

  /// Shown when there are no archived pets.
  static const empty = 'No archived pets';

  /// Shown when the archived pets can't be read before any have been.
  static const loadFailed =
      "Your archived pets couldn't be loaded. Close the app and open it again.";

  /// Opens the archived pets over [context]'s screen.
  static void open(BuildContext context, Clock clock) => unawaited(
    Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => ArchivedPetsScreen(clock: clock)),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Archived pets')),
      body: PetNameList(
        watch: (pets) => pets.watchArchived(),
        clock: clock,
        what: 'Reading the archived pets',
        loadFailed: loadFailed,
        empty: empty,
      ),
    );
  }
}
