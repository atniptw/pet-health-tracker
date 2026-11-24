import 'dart:async';

import '../../domain/event_type.dart';
import '../../domain/pet.dart';
import '../app_scope.dart';
import 'read_failure.dart';

/// Follows the active pets and offered types in an [AppScope]'s
/// repositories. A failed read is reported to the app's error handler and
/// sends nothing, so the last lists sent stay the latest.
class ActivePetsAndTypes {
  StreamSubscription<List<Pet>>? _pets;
  StreamSubscription<List<EventType>>? _types;

  /// Stops following the repositories followed before, if any, and sends
  /// each list read from [scope]'s to [onPets] or [onTypes].
  void follow(
    AppScope scope, {
    required void Function(List<Pet> pets) onPets,
    required void Function(List<EventType> types) onTypes,
  }) {
    cancel();
    _pets = scope.pets.watchActive().listen(
      onPets,
      onError: (Object _, StackTrace stack) => reportReadFailure('Reading the active pets', stack),
    );
    _types = scope.eventTypes.watchOffered().listen(
      onTypes,
      onError: (Object _, StackTrace stack) => reportReadFailure('Reading the event types', stack),
    );
  }

  /// Stops following the repositories.
  void cancel() {
    unawaited(_pets?.cancel());
    unawaited(_types?.cancel());
  }
}
