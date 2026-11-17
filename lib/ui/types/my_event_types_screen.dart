import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/repositories.dart';
import '../../domain/event_type.dart';
import '../app_scope.dart';
import '../common/centered_message.dart';
import '../common/read_failure.dart';

/// The custom types still offered, each with "Remove", which takes the type
/// out of the list with nothing more asked; past events keep it (FR-004).
///
/// A failed read is reported to the app's error handler and keeps the last
/// list read; before any has been read, it shows [loadFailed].
class MyEventTypesScreen extends StatefulWidget {
  const MyEventTypesScreen({super.key});

  /// Shown when there are no custom types.
  static const empty = 'Types you type in yourself appear here';

  /// Shown when the custom types can't be read before any have been.
  static const loadFailed = "Your event types couldn't be loaded. Close the app and open it again.";

  @override
  State<MyEventTypesScreen> createState() => _MyEventTypesScreenState();
}

class _MyEventTypesScreenState extends State<MyEventTypesScreen> {
  EventTypeRepository? _repository;
  StreamSubscription<List<EventType>>? _subscription;
  List<EventType>? _types;
  bool _failed = false;

  /// The ids of the types being removed, whose "Remove" is disabled.
  final _removing = <String>{};

  /// Before the first build, and whenever [AppScope] holds another event
  /// type repository than before, reads the custom types from it.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final repository = AppScope.of(context).eventTypes;
    if (repository == _repository) return;
    unawaited(_subscription?.cancel());
    _repository = repository;
    _types = null;
    _failed = false;
    _removing.clear();
    _subscription = repository.watchCustom().listen(
      (types) => setState(() {
        _types = types;
        _failed = false;
      }),
      onError: (Object _, StackTrace stack) {
        reportReadFailure('Reading the custom event types', stack);
        setState(() => _failed = true);
      },
    );
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  Future<void> _remove(EventType type) async {
    if (!_removing.add(type.id)) return;
    setState(() {});
    final repository = _repository!;
    try {
      await repository.remove(type.id);
    } catch (_, stack) {
      // "Remove" works again. The app's error handler gets an error without
      // the write's own message, which can hold the type's name.
      _doneRemoving(type, repository);
      Error.throwWithStackTrace(StateError('Removing the event type failed'), stack);
    }
    _doneRemoving(type, repository);
  }

  void _doneRemoving(EventType type, EventTypeRepository repository) {
    if (mounted && repository == _repository) setState(() => _removing.remove(type.id));
  }

  Widget _list(List<EventType> types) => ListView(
    children: [
      for (final type in types)
        ListTile(
          title: Text(type.name),
          trailing: TextButton(
            onPressed: _removing.contains(type.id) ? null : () => _remove(type),
            child: const Text('Remove'),
          ),
        ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My event types')),
      body: switch (_types) {
        null when _failed => const CenteredMessage(MyEventTypesScreen.loadFailed),
        null => const SizedBox.shrink(),
        [] => const CenteredMessage(MyEventTypesScreen.empty),
        final types => _list(types),
      },
    );
  }
}
