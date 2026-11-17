import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/repositories.dart';
import '../../domain/pet.dart';
import '../app_scope.dart';
import '../common/centered_message.dart';
import '../common/watched_view.dart';
import '../history/pet_history_screen.dart';

/// The pets [watch] reads from [AppScope]'s pet repository, by name, each
/// opening its history; with none, [empty] if given.
///
/// A failed read is reported to the app's error handler as [what] failing
/// and keeps the last list read; before any has been read, it shows
/// [loadFailed].
class PetNameList extends StatefulWidget {
  const PetNameList({
    super.key,
    required this.watch,
    required this.clock,
    required this.what,
    required this.loadFailed,
    this.empty,
  });

  /// Reads the pets to list from a repository.
  final Stream<List<Pet>> Function(PetRepository pets) watch;

  /// Passed to the pet history the list opens.
  final Clock clock;

  /// What the read is, as in "Reading the pets".
  final String what;

  /// Shown when the pets can't be read before any have been.
  final String loadFailed;

  /// Shown when there are no pets.
  final String? empty;

  @override
  State<PetNameList> createState() => _PetNameListState();
}

class _PetNameListState extends State<PetNameList> {
  PetRepository? _repository;
  late Stream<List<Pet>> _pets;

  /// Before the first build, and whenever [AppScope] holds another pet
  /// repository than before, reads the pets from it.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final repository = AppScope.of(context).pets;
    if (repository == _repository) return;
    _repository = repository;
    _pets = widget.watch(repository);
  }

  void _openHistory(Pet pet) => unawaited(
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => PetHistoryScreen(pet: pet, clock: widget.clock),
      ),
    ),
  );

  Widget _list(List<Pet> pets) {
    final empty = widget.empty;
    if (pets.isEmpty && empty != null) return CenteredMessage(empty);
    return ListView(
      children: [
        for (final pet in pets) ListTile(title: Text(pet.name), onTap: () => _openHistory(pet)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => WatchedView(
    stream: _pets,
    what: widget.what,
    loadFailed: widget.loadFailed,
    builder: (context, pets) => _list(pets),
  );
}
