import 'package:flutter/material.dart';

import '../../data/repositories.dart';
import '../../domain/event_type.dart';
import '../../domain/medical_event.dart';
import '../../domain/pet.dart';
import '../app_scope.dart';
import '../common/date_time_field.dart';
import '../common/event_fields.dart';
import 'pet_choices.dart';

/// Logs one event of a type for one pet: the type name and the pet, then
/// the event's fields and "Save". Closes with the saved [MedicalEvent].
///
/// When [pickedPetId] isn't one of [pets], the pet choices show for the
/// sheet's life (D-010) and "Save" is disabled until one is picked.
class LogSheet extends StatefulWidget {
  /// Logs an event of [type], with its detail questions.
  LogSheet.forType(
    EventType type, {
    super.key,
    required this.pets,
    required this.pickedPetId,
    required this.clock,
  }) : choice = ExistingType(type.id),
       typeName = type.name,
       questions = type.questions;

  /// Logs an event of a type the caregiver named in their own words, which
  /// has no detail questions.
  LogSheet.forNewName(
    String name, {
    super.key,
    required this.pets,
    required this.pickedPetId,
    required this.clock,
  }) : choice = NewTypeName(name),
       typeName = name,
       questions = const [];

  final TypeChoice choice;
  final String typeName;
  final List<DetailQuestion> questions;

  /// The active pets.
  final List<Pet> pets;

  /// The pet already picked, or null when none is.
  final String? pickedPetId;

  final Clock clock;

  @override
  State<LogSheet> createState() => _LogSheetState();
}

typedef _Repositories = ({
  PetRepository pets,
  EventTypeRepository eventTypes,
  EventRepository events,
});

class _LogSheetState extends State<LogSheet> {
  late String? _petId = widget.pickedPetId;
  late final bool _choosingPet = !_isActive(widget.pickedPetId);
  final _note = TextEditingController();
  DateTime? _when;
  Map<String, Object> _details = const {};
  var _futureOnSave = false;
  var _saving = false;

  /// The repositories in [AppScope] when the sheet opened, which [pets]
  /// and [pickedPetId] came from.
  _Repositories? _repositories;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _repositories ??= _scopeRepositories();
  }

  _Repositories _scopeRepositories() {
    final scope = AppScope.of(context);
    return (pets: scope.pets, eventTypes: scope.eventTypes, events: scope.events);
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  bool _isActive(String? petId) => widget.pets.any((pet) => pet.id == petId);

  /// Saves the event through the repositories the sheet opened with, or
  /// closes without saving when [AppScope] holds other ones by now.
  Future<void> _save() async {
    if (_scopeRepositories() != _repositories) {
      Navigator.pop(context);
      return;
    }
    final occurredAt = _when ?? widget.clock();
    if (occurredAt.isAfter(widget.clock())) {
      setState(() => _futureOnSave = true);
      return;
    }
    setState(() => _saving = true);
    final MedicalEvent event;
    try {
      event = await _repositories!.events.log(
        petId: _petId!,
        type: widget.choice,
        occurredAt: occurredAt,
        details: _details,
        note: _note.text,
      );
    } catch (_, stack) {
      // Save works again. The app's error handler gets an error without the
      // write's own message, which can hold the note.
      if (mounted) setState(() => _saving = false);
      Error.throwWithStackTrace(StateError('Logging the event failed'), stack);
    }
    if (mounted) Navigator.pop(context, event);
  }

  Widget _header(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(widget.typeName, style: textTheme.titleLarge),
        const SizedBox(height: 8),
        if (_choosingPet)
          PetChoices(
            pets: widget.pets,
            pickedId: _petId,
            onPicked: (id) => setState(() => _petId = id),
          )
        else
          Text(
            widget.pets.firstWhere((pet) => pet.id == _petId).name,
            style: textTheme.titleMedium,
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            _header(context),
            const SizedBox(height: 16),
            EventFields(
              clock: widget.clock,
              when: _when,
              onWhenChanged: (when) => setState(() {
                _when = when;
                _futureOnSave = false;
              }),
              whenError: _futureOnSave ? futureTimeError : null,
              questions: widget.questions,
              onDetailsChanged: (details) => _details = details,
              note: _note,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _isActive(_petId) && !_saving ? _save : null,
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
