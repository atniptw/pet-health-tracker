import 'package:flutter/material.dart';

import '../../data/repositories.dart';
import '../../domain/event_type.dart';
import '../../domain/medical_event.dart';
import '../../domain/pet.dart';
import '../app_scope.dart';
import '../common/active_pets_and_types.dart';
import '../common/event_fields.dart';
import '../log/pet_choices.dart';

/// "Event": a logged event's pet, type, "When", details and note, filled in
/// and editable (FR-011, story 1 scenario 8). The pets are the active ones
/// plus the event's own, and the types the offered ones plus the event's
/// own, so an archived pet or a removed type stays choosable. Changing the
/// type keeps only the details its questions share. "Save" applies the
/// changes and returns to the pet history. "Delete" asks "Delete this
/// event?" first, then deletes the event and returns to the pet history.
///
/// A failed read of the pets or types is reported to the app's error handler
/// and keeps the choices shown, which always hold the event's own.
class EventScreen extends StatefulWidget {
  const EventScreen({
    super.key,
    required this.event,
    required this.pet,
    required this.type,
    required this.clock,
  });

  final MedicalEvent event;

  /// [event]'s pet, archived or not.
  final Pet pet;

  /// [event]'s type, removed or not.
  final EventType type;

  final Clock clock;

  @override
  State<EventScreen> createState() => _EventScreenState();
}

class _EventScreenState extends State<EventScreen> {
  (PetRepository, EventTypeRepository)? _repositories;
  final _following = ActivePetsAndTypes();
  List<Pet> _activePets = const [];
  List<EventType> _offeredTypes = const [];

  late String _petId = widget.event.petId;
  late EventType _type = widget.type;
  late DateTime _when = widget.event.occurredAt;
  late Map<String, Object> _details = widget.event.details;
  late final _note = TextEditingController(text: widget.event.note);
  var _saving = false;
  var _deleting = false;

  /// Whether a save or delete is in flight, which disables both buttons.
  bool get _busy => _saving || _deleting;

  /// Before the first build, and whenever [AppScope] holds other
  /// repositories than before, follows the active pets and offered types in
  /// them.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scope = AppScope.of(context);
    final repositories = (scope.pets, scope.eventTypes);
    if (repositories == _repositories) return;
    _repositories = repositories;
    _following.follow(
      scope,
      onPets: (pets) => setState(() => _activePets = pets),
      onTypes: (types) => setState(() => _offeredTypes = types),
    );
  }

  @override
  void dispose() {
    _following.cancel();
    _note.dispose();
    super.dispose();
  }

  List<Pet> get _pets => [
    ..._activePets,
    if (!_activePets.any((pet) => pet.id == widget.pet.id)) widget.pet,
  ];

  List<EventType> get _types => [
    ..._offeredTypes,
    if (!_offeredTypes.any((type) => type.id == widget.type.id)) widget.type,
  ];

  void _pickType(String? id) {
    final type = _types.firstWhere((type) => type.id == id);
    setState(() {
      _type = type;
      _details = detailsKeptFor(type, _details);
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await AppScope.of(context).events.update(
        widget.event.id,
        petId: _petId,
        type: ExistingType(_type.id),
        occurredAt: _when,
        details: _details,
        note: _note.text,
      );
    } catch (_, stack) {
      // Save works again. The app's error handler gets an error without the
      // write's own message, which can hold the note.
      if (mounted) setState(() => _saving = false);
      Error.throwWithStackTrace(StateError('Saving the event failed'), stack);
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this event?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _deleting = true);
    try {
      await AppScope.of(context).events.delete(widget.event.id);
    } catch (_, stack) {
      // Delete works again. The app's error handler gets an error without
      // the write's own message.
      if (mounted) setState(() => _deleting = false);
      Error.throwWithStackTrace(StateError('Deleting the event failed'), stack);
    }
    if (mounted) Navigator.pop(context);
  }

  Widget _typeField() => DropdownButtonFormField<String>(
    initialValue: _type.id,
    decoration: const InputDecoration(labelText: 'Type'),
    isExpanded: true,
    items: [
      for (final type in _types)
        DropdownMenuItem(
          value: type.id,
          child: Text(type.name, overflow: TextOverflow.ellipsis),
        ),
    ],
    onChanged: _pickType,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Event'),
        actions: [TextButton(onPressed: _busy ? null : _delete, child: const Text('Delete'))],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PetChoices(
              pets: _pets,
              pickedId: _petId,
              onPicked: (id) => setState(() => _petId = id),
            ),
            const SizedBox(height: 16),
            _typeField(),
            const SizedBox(height: 16),
            EventFields(
              // A new type starts its questions over from the kept details.
              key: ValueKey(_type.id),
              clock: widget.clock,
              when: _when,
              onWhenChanged: (when) => setState(() => _when = when),
              questions: _type.questions,
              initialDetails: _details,
              onDetailsChanged: (details) => _details = details,
              note: _note,
            ),
            const SizedBox(height: 24),
            FilledButton(onPressed: _busy ? null : _save, child: const Text('Save')),
          ],
        ),
      ),
    );
  }
}
