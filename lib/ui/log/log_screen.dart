import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/repositories.dart';
import '../../domain/event_type.dart';
import '../../domain/medical_event.dart';
import '../../domain/pet.dart';
import '../app_scope.dart';
import '../common/active_pets_and_types.dart';
import '../common/read_failure.dart';
import '../history/pet_history_screen.dart';
import '../pets/pets_screen.dart';
import '../types/my_event_types_screen.dart';
import 'log_sheet.dart';
import 'pet_choices.dart';
import 'something_else_sheet.dart';
import 'type_grid.dart';

/// The home screen: the pet an event is for, and a button per offered type
/// that opens the log sheet, and "Something else" for a type in the
/// caregiver's own words. After a save, a "Saved" message naming the
/// type and the pet. "History" opens the picked pet's history, and is
/// disabled while none is picked. Its menu opens Pets and My event types.
///
/// With one active pet, that pet is picked and shown as a heading. With
/// several, the pet choices show, with the pet last logged for picked if it
/// is active; none is picked otherwise, or when that read fails (FR-007). A
/// saved event's pet becomes the picked one.
class LogScreen extends StatefulWidget {
  const LogScreen({super.key, required this.clock});

  final Clock clock;

  @override
  State<LogScreen> createState() => _LogScreenState();
}

class _LogScreenState extends State<LogScreen> {
  PetRepository? _petRepository;
  EventTypeRepository? _typeRepository;
  EventRepository? _eventRepository;
  final _following = ActivePetsAndTypes();
  List<Pet> _pets = const [];
  List<EventType> _types = const [];
  String? _pickedId;

  /// Before the first build, and whenever [AppScope] holds other
  /// repositories than before, follows the pets and types in them and reads
  /// the pick. Other dependency changes keep the pick. A failed read keeps
  /// the last pets or types read.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scope = AppScope.of(context);
    if (scope.pets == _petRepository &&
        scope.eventTypes == _typeRepository &&
        scope.events == _eventRepository) {
      return;
    }
    _petRepository = scope.pets;
    _typeRepository = scope.eventTypes;
    _eventRepository = scope.events;
    _pets = const [];
    _types = const [];
    _following.follow(
      scope,
      onPets: (pets) => setState(() => _pets = pets),
      onTypes: (types) => setState(() => _types = types),
    );
    _pickedId = null;
    unawaited(_loadLastLogged(scope.events));
  }

  @override
  void dispose() {
    _following.cancel();
    super.dispose();
  }

  /// Picks the pet last logged for in [events], unless a pet was picked
  /// meanwhile or the screen has moved to other repositories. A failed read
  /// is reported and picks no pet.
  Future<void> _loadLastLogged(EventRepository events) async {
    final String? id;
    try {
      id = await events.lastLoggedPetId();
    } on Object catch (_, stack) {
      reportReadFailure('Reading the last logged pet', stack);
      return;
    }
    if (mounted && _pickedId == null && events == _eventRepository) {
      setState(() => _pickedId = id);
    }
  }

  /// The picked pet's id among [pets], or null when none is picked.
  String? _pickedAmong(List<Pet> pets) {
    if (pets.length == 1) return pets.single.id;
    return pets.any((pet) => pet.id == _pickedId) ? _pickedId : null;
  }

  Future<void> _log(EventType type, List<Pet> pets) => _open(
    LogSheet.forType(type, pets: pets, pickedPetId: _pickedAmong(pets), clock: widget.clock),
    pets,
  );

  /// Asks "What happened?", then opens the log sheet for the typed name,
  /// unless the screen has moved to other repositories meanwhile, since
  /// [pets] are the earlier ones' pets.
  Future<void> _logSomethingElse(List<Pet> pets) async {
    final repositories = _repositories;
    final types = _typeRepository!;
    final name = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const SomethingElseSheet(),
    );
    if (name == null || !mounted || _repositories != repositories) return;
    final sheet = logSheetFor(
      name,
      types,
      pets: pets,
      pickedPetId: _pickedAmong(pets),
      clock: widget.clock,
    );
    await _open(sheet, pets);
  }

  (PetRepository?, EventTypeRepository?, EventRepository?) get _repositories =>
      (_petRepository, _typeRepository, _eventRepository);

  /// Shows [sheet]; after a save, picks the event's pet and shows the
  /// "Saved" message.
  Future<void> _open(LogSheet sheet, List<Pet> pets) async {
    final event = await showModalBottomSheet<MedicalEvent>(
      context: context,
      isScrollControlled: true,
      builder: (_) => sheet,
    );
    if (event == null || !mounted) return;
    setState(() => _pickedId = event.petId);
    final pet = pets.firstWhere((pet) => pet.id == event.petId);
    ScaffoldMessenger.of(context)
      ..removeCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('Saved: ${sheet.typeName} for ${pet.name}')));
  }

  void _openPets() => unawaited(
    Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => PetsScreen(clock: widget.clock)),
    ),
  );

  void _openMyEventTypes() => unawaited(
    Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const MyEventTypesScreen())),
  );

  void _openHistory(Pet pet) => unawaited(
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => PetHistoryScreen(pet: pet, clock: widget.clock),
      ),
    ),
  );

  Widget _pet(BuildContext context, List<Pet> pets) {
    if (pets.length == 1) {
      return Semantics(
        header: true,
        child: Text(pets.single.name, style: Theme.of(context).textTheme.headlineSmall),
      );
    }
    return PetChoices(
      pets: pets,
      pickedId: _pickedAmong(pets),
      onPicked: (id) => setState(() => _pickedId = id),
    );
  }

  Widget _body(List<Pet> pets) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _pet(context, pets),
        const SizedBox(height: 16),
        TypeGrid(
          types: _types,
          onTap: (type) => _log(type, pets),
          onSomethingElse: () => _logSomethingElse(pets),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final pets = _pets;
    final pickedId = _pickedAmong(pets);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Log'),
        actions: [
          TextButton(
            onPressed: pickedId == null
                ? null
                : () => _openHistory(pets.firstWhere((pet) => pet.id == pickedId)),
            child: const Text('History'),
          ),
          PopupMenuButton<void>(
            tooltip: 'Menu',
            itemBuilder: (_) => [
              PopupMenuItem(onTap: _openPets, child: const Text('Pets')),
              PopupMenuItem(onTap: _openMyEventTypes, child: const Text('My event types')),
            ],
          ),
        ],
      ),
      body: _body(pets),
    );
  }
}
