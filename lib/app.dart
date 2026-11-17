import 'dart:async';

import 'package:flutter/material.dart';

import 'data/repositories.dart';
import 'domain/pet.dart';
import 'ui/app_scope.dart';
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
  StreamSubscription<List<Pet>>? _subscription;
  List<Pet>? _active;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _listen();
  }

  @override
  void didUpdateWidget(_StartScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pets == oldWidget.pets) return;
    unawaited(_subscription?.cancel());
    _active = null;
    _failed = false;
    _listen();
  }

  void _listen() {
    _subscription = widget.pets.watchActive().listen(
      (active) => setState(() {
        _active = active;
        _failed = false;
      }),
      onError: (Object _, StackTrace stack) {
        // The read's own message can hold a pet's name, so the report
        // leaves it out.
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: StateError('Reading the active pets failed'),
            stack: stack,
          ),
        );
        setState(() => _failed = true);
      },
    );
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return switch (_active) {
      null when _failed => const Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(App.loadFailed, textAlign: TextAlign.center),
          ),
        ),
      ),
      null => const Scaffold(),
      [] => const FirstPetScreen(),
      _ => LogScreen(clock: widget.clock),
    };
  }
}
