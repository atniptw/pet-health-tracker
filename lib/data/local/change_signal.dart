import 'dart:async';

/// Tells a repository's open streams that a write happened, so each reads
/// again.
class ChangeSignal {
  final _changes = StreamController<void>.broadcast(sync: true);

  /// Makes every stream from [watch] that has a listener read again.
  void notify() => _changes.add(null);

  /// Emits [read] on listen and again after each [notify], until cancelled.
  /// A failed read is emitted as an error.
  Stream<T> watch<T>(Future<T> Function() read) {
    late final StreamController<T> controller;
    StreamSubscription<void>? changes;
    Future<void> emit() async {
      try {
        final value = await read();
        if (!controller.isClosed) controller.add(value);
      } catch (error, stack) {
        if (!controller.isClosed) controller.addError(error, stack);
      }
    }

    controller = StreamController<T>(
      onListen: () {
        changes = _changes.stream.listen((_) => unawaited(emit()));
        unawaited(emit());
      },
      onCancel: () {
        unawaited(controller.close());
        return changes?.cancel();
      },
    );
    return controller.stream;
  }
}
