import 'dart:async';

import 'package:flutter/widgets.dart';

import 'centered_message.dart';
import 'read_failure.dart';

/// Shows the latest value of [stream] through [builder], and nothing before
/// the first one.
///
/// A failed read is reported to the app's error handler as [what] failing,
/// and keeps the last value shown; before any value has been read, it shows
/// [loadFailed]. Another [stream] is listened to from the start, so the
/// stream has to be kept between builds rather than made in one.
class WatchedView<T> extends StatefulWidget {
  const WatchedView({
    super.key,
    required this.stream,
    required this.what,
    required this.loadFailed,
    required this.builder,
  });

  final Stream<T> stream;

  /// What the read is, as in "Reading the custom event types".
  final String what;

  /// Shown when [stream] fails before any value has been read.
  final String loadFailed;

  final Widget Function(BuildContext context, T value) builder;

  @override
  State<WatchedView<T>> createState() => _WatchedViewState<T>();
}

class _WatchedViewState<T> extends State<WatchedView<T>> {
  StreamSubscription<T>? _subscription;

  /// The last value read, wrapped so that a null value counts as read.
  ({T value})? _latest;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _listen();
  }

  @override
  void didUpdateWidget(WatchedView<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.stream == oldWidget.stream) return;
    unawaited(_subscription?.cancel());
    _latest = null;
    _failed = false;
    _listen();
  }

  void _listen() {
    _subscription = widget.stream.listen(
      (value) => setState(() {
        _latest = (value: value);
        _failed = false;
      }),
      onError: (Object _, StackTrace stack) {
        reportReadFailure(widget.what, stack);
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
  Widget build(BuildContext context) => switch (_latest) {
    null when _failed => CenteredMessage(widget.loadFailed),
    null => const SizedBox.shrink(),
    (:final value) => widget.builder(context, value),
  };
}
