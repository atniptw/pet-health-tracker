import 'package:flutter/material.dart';

import 'data/repositories.dart';
import 'domain/pet.dart';
import 'ui/app_scope.dart';
import 'ui/common/watched_view.dart';
import 'ui/log/log_screen.dart';
import 'ui/pets/first_pet_screen.dart';

/// The app on the given repositories: the first pet screen while there are
/// no active pets, and the log screen otherwise.
class App extends StatelessWidget {
  const App({
    super.key,
    required this.pets,
    required this.eventTypes,
    required this.events,
    required this.clock,
  });

  final PetRepository pets;
  final EventTypeRepository eventTypes;
  final EventRepository events;
  final Clock clock;

  /// Shown when the active pets can't be read before any have been.
  static const loadFailed = "Your pets couldn't be loaded. Close the app and open it again.";

  @override
  Widget build(BuildContext context) {
    return AppScope(
      pets: pets,
      eventTypes: eventTypes,
      events: events,
      child: MaterialApp(
        title: 'Pet Health Tracker',
        home: _StartScreen(pets: pets, clock: clock),
      ),
    );
  }
}

/// Follows the active pets and shows the screen they call for, keeping the
/// log screen's state while pets are added or changed.
///
/// A failed read is reported to the app's error handler and keeps the last
/// pets read; before any have been read, it shows [App.loadFailed].
class _StartScreen extends StatefulWidget {
  const _StartScreen({required this.pets, required this.clock});

  final PetRepository pets;
  final Clock clock;

  @override
  State<_StartScreen> createState() => _StartScreenState();
}

class _StartScreenState extends State<_StartScreen> {
  late Stream<List<Pet>> _active = widget.pets.watchActive();

  @override
  void didUpdateWidget(_StartScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pets != oldWidget.pets) _active = widget.pets.watchActive();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      child: WatchedView(
        stream: _active,
        what: 'Reading the active pets',
        loadFailed: App.loadFailed,
        builder: (context, active) =>
            active.isEmpty ? FirstPetScreen(clock: widget.clock) : LogScreen(clock: widget.clock),
      ),
    );
  }
}
