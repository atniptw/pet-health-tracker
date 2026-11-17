import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/repositories.dart';
import '../../domain/pet.dart';
import '../app_scope.dart';
import '../common/watched_view.dart';
import '../history/pet_history_screen.dart';
import 'pet_form_screen.dart';

/// The active pets by name, each opening its history, and "Add pet", which
/// opens the pet form.
///
/// A failed read is reported to the app's error handler and keeps the last
/// list read; before any has been read, it shows [loadFailed].
class PetsScreen extends StatefulWidget {
  const PetsScreen({super.key, required this.clock});

  /// Passed to the pet history the screen opens.
  final Clock clock;

  /// Shown when the pets can't be read before any have been.
  static const loadFailed = "Your pets couldn't be loaded. Close the app and open it again.";

  @override
  State<PetsScreen> createState() => _PetsScreenState();
}

class _PetsScreenState extends State<PetsScreen> {
  PetRepository? _repository;
  late Stream<List<Pet>> _pets;

  /// Before the first build, and whenever [AppScope] holds another pet
  /// repository than before, reads the active pets from it.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final repository = AppScope.of(context).pets;
    if (repository == _repository) return;
    _repository = repository;
    _pets = repository.watchActive();
  }

  void _openHistory(Pet pet) => unawaited(
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => PetHistoryScreen(pet: pet, clock: widget.clock),
      ),
    ),
  );

  void _addPet() => unawaited(
    Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const PetFormScreen())),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pets'),
        actions: [TextButton(onPressed: _addPet, child: const Text('Add pet'))],
      ),
      body: WatchedView(
        stream: _pets,
        what: 'Reading the pets',
        loadFailed: PetsScreen.loadFailed,
        builder: (context, pets) => ListView(
          children: [
            for (final pet in pets) ListTile(title: Text(pet.name), onTap: () => _openHistory(pet)),
          ],
        ),
      ),
    );
  }
}
