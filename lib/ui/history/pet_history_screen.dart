import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/repositories.dart';
import '../../domain/event_type.dart';
import '../../domain/frequency.dart';
import '../../domain/medical_event.dart';
import '../../domain/pet.dart';
import '../app_scope.dart';
import '../common/read_failure.dart';
import '../common/watched_view.dart';
import '../pets/pet_form_screen.dart';
import 'event_tile.dart';
import 'type_summary.dart';

/// A pet's history: its name as the title, how often each type happened
/// (FR-010), then its events newest first, each with the time since the
/// previous one of its type over the pet's whole history (FR-008, FR-009).
/// "Edit pet" opens the pet form, and the title follows the pet's name.
///
/// A failed read is reported to the app's error handler and keeps what is
/// shown; before any events have been read, it shows [loadFailed].
class PetHistoryScreen extends StatefulWidget {
  const PetHistoryScreen({super.key, required this.pet, required this.clock});

  /// The pet as it was when the screen opened.
  final Pet pet;

  /// Reads the moment the summary's periods end at.
  final Clock clock;

  /// Shown when the pet's events can't be read before any have been.
  static const loadFailed =
      "This pet's history couldn't be loaded. Close the app and open it again.";

  @override
  State<PetHistoryScreen> createState() => _PetHistoryScreenState();
}

/// A pet's events, newest first, and their types by id.
typedef _History = ({List<MedicalEvent> events, Map<String, EventType> types});

class _PetHistoryScreenState extends State<PetHistoryScreen> {
  (PetRepository, EventTypeRepository, EventRepository)? _repositories;
  StreamSubscription<Pet?>? _petSubscription;
  late Stream<_History> _history;
  late Pet _pet = widget.pet;

  /// Before the first build, and whenever [AppScope] holds other
  /// repositories than before, follows the pet and its events in them.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scope = AppScope.of(context);
    final repositories = (scope.pets, scope.eventTypes, scope.events);
    if (repositories == _repositories) return;
    _repositories = repositories;
    unawaited(_petSubscription?.cancel());
    _petSubscription = scope.pets
        .watch(widget.pet.id)
        .listen(
          (pet) => setState(() => _pet = pet ?? _pet),
          onError: (Object _, StackTrace stack) => reportReadFailure('Reading the pet', stack),
        );
    _history = scope.events
        .watchForPet(widget.pet.id)
        .asyncMap((events) => _withTypes(events, scope.eventTypes));
  }

  /// [events] with the type of each, removed or not, through [types].
  static Future<_History> _withTypes(List<MedicalEvent> events, EventTypeRepository types) async {
    final ids = {for (final event in events) event.typeId};
    final found = await Future.wait(ids.map(types.byId));
    return (events: events, types: Map.fromIterables(ids, found));
  }

  @override
  void dispose() {
    unawaited(_petSubscription?.cancel());
    super.dispose();
  }

  void _editPet() => unawaited(
    Navigator.push(context, MaterialPageRoute<void>(builder: (_) => PetFormScreen(pet: _pet))),
  );

  Widget _list(_History history) {
    final (:events, :types) = history;
    return ListView(
      children: [
        TypeSummaryList(events: events, now: widget.clock(), typeName: (id) => types[id]!.name),
        const Divider(),
        for (final event in events)
          EventTile(
            event: event,
            type: types[event.typeId]!,
            gap: timeSincePrevious(event, events),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_pet.name),
        actions: [TextButton(onPressed: _editPet, child: const Text('Edit pet'))],
      ),
      body: WatchedView(
        stream: _history,
        what: "Reading the pet's history",
        loadFailed: PetHistoryScreen.loadFailed,
        builder: (context, history) => _list(history),
      ),
    );
  }
}
