import 'package:flutter/material.dart';

import '../../data/repositories.dart';
import '../../domain/pet.dart';
import '../app_scope.dart';
import '../common/watched_view.dart';
import 'archived_pets_screen.dart';
import 'pet_form.dart';

/// Asks for the first pet with the pet form. Once saved, "Save" stays
/// disabled and the screen stays put: the app's start screen choice, which
/// follows the active pets, replaces it.
///
/// While there are archived pets, "See archived pets" opens them. A failed
/// read of them is reported to the app's error handler and leaves the link
/// out until they are read.
class FirstPetScreen extends StatefulWidget {
  const FirstPetScreen({super.key, required this.clock});

  /// Passed to the archived pets screen.
  final Clock clock;

  @override
  State<FirstPetScreen> createState() => _FirstPetScreenState();
}

class _FirstPetScreenState extends State<FirstPetScreen> {
  PetRepository? _repository;
  late Stream<List<Pet>> _archived;

  /// Before the first build, and whenever [AppScope] holds another pet
  /// repository than before, reads the archived pets from it.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final repository = AppScope.of(context).pets;
    if (repository == _repository) return;
    _repository = repository;
    _archived = repository.watchArchived();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add your first pet')),
      body: Column(
        children: [
          const Expanded(child: PetForm()),
          WatchedView(
            stream: _archived,
            what: 'Reading the archived pets',
            builder: (context, archived) => archived.isEmpty
                ? const SizedBox.shrink()
                : SafeArea(
                    top: false,
                    child: TextButton(
                      onPressed: () => ArchivedPetsScreen.open(context, widget.clock),
                      child: const Text('See archived pets'),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
