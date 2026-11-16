import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/repositories.dart';
import '../../domain/event_type.dart';
import '../../domain/medical_event.dart';
import '../../domain/pet.dart';
import '../app_scope.dart';
import 'log_sheet.dart';
import 'pet_choices.dart';
import 'type_grid.dart';

/// The home screen: the pet an event is for, and a button per offered type
/// that opens the log sheet. After a save, a "Saved" message naming the
/// type and the pet.
///
/// With one active pet, that pet is picked and shown as a heading. With
/// several, the pet choices show, with the pet last logged for picked if it
/// is active and none otherwise (FR-007); a saved event's pet becomes the
/// picked one.
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
  late Stream<List<Pet>> _pets;
  late Stream<List<EventType>> _types;
  String? _pickedId;

  /// Before the first build, and whenever [AppScope] holds other
  /// repositories than before, reads the pets, types and pick from them.
  /// Other dependency changes keep the pick.
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
    _pets = scope.pets.watchActive();
    _types = scope.eventTypes.watchOffered();
    _pickedId = null;
    unawaited(_loadLastLogged(scope.events));
  }

  /// Picks the pet last logged for in [events], unless a pet was picked
  /// meanwhile or the screen has moved to other repositories.
  Future<void> _loadLastLogged(EventRepository events) async {
    final id = await events.lastLoggedPetId();
    if (mounted && _pickedId == null && events == _eventRepository) {
      setState(() => _pickedId = id);
    }
  }

  /// The picked pet's id among [pets], or null when none is picked.
  String? _pickedAmong(List<Pet> pets) {
    if (pets.length == 1) return pets.single.id;
    return pets.any((pet) => pet.id == _pickedId) ? _pickedId : null;
  }

  Future<void> _log(EventType type, List<Pet> pets) async {
    final event = await showModalBottomSheet<MedicalEvent>(
      context: context,
      isScrollControlled: true,
      builder: (_) =>
          LogSheet.forType(type, pets: pets, pickedPetId: _pickedAmong(pets), clock: widget.clock),
    );
    if (event == null || !mounted) return;
    setState(() => _pickedId = event.petId);
    final pet = pets.firstWhere((pet) => pet.id == event.petId);
    ScaffoldMessenger.of(context)
      ..removeCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('Saved: ${type.name} for ${pet.name}')));
  }

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
    return StreamBuilder<List<EventType>>(
      stream: _types,
      builder: (context, types) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _pet(context, pets),
          const SizedBox(height: 16),
          TypeGrid(types: types.data ?? const [], onTap: (type) => _log(type, pets)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Log')),
      body: StreamBuilder<List<Pet>>(
        stream: _pets,
        builder: (context, pets) => _body(pets.data ?? const []),
      ),
    );
  }
}
