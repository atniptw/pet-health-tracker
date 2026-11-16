import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pet_health_tracker/data/local/change_signal.dart';

void main() {
  late ChangeSignal signal;
  late int reads;

  /// Counts each read and returns the count.
  Future<int> read() async => ++reads;

  setUp(() {
    signal = ChangeSignal();
    reads = 0;
  });

  test('emits a read on listen', () async {
    expect(await signal.watch(read).first, 1);
  });

  test('emits again after each notify, on every open stream', () async {
    final first = StreamIterator(signal.watch(read));
    final second = StreamIterator(signal.watch(read));
    addTearDown(() => [first, second].map((s) => s.cancel()).wait);
    expect(await first.moveNext(), isTrue);
    expect(await second.moveNext(), isTrue);

    signal.notify();
    expect(await first.moveNext(), isTrue);
    expect(await second.moveNext(), isTrue);

    expect(reads, 4);
  });

  test('a failed read is emitted as an error', () async {
    final stream = signal.watch<int>(() async => throw StateError('closed'));

    await expectLater(stream, emitsError(isStateError));
  });

  test('after cancel, notify reads nothing', () async {
    final stream = StreamIterator(signal.watch(read));
    expect(await stream.moveNext(), isTrue);
    await stream.cancel();

    signal.notify();
    await pumpEventQueue();

    expect(reads, 1);
  });

  test('a read still running at cancel finishes without adding to the closed stream', () async {
    final pending = Completer<int>();
    final subscription = signal
        .watch(() => pending.future)
        .listen((_) => fail('emitted after cancel'));

    await subscription.cancel();
    pending.complete(1);
    await pumpEventQueue();
  });

  test('a read failing after cancel adds no error to the closed stream', () async {
    final pending = Completer<int>();
    final subscription = signal
        .watch(() => pending.future)
        .listen((_) {}, onError: (Object _) => fail('error after cancel'));

    await subscription.cancel();
    pending.completeError(StateError('closed'));
    await pumpEventQueue();
  });
}
