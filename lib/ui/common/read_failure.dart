import 'package:flutter/foundation.dart';

/// Reports a failed read to the app's error handler as a [StateError]
/// saying [what] failed, with [stack]. The read's own error is left out,
/// since its message can hold the caregiver's data, such as a name.
void reportReadFailure(String what, StackTrace stack) {
  FlutterError.reportError(
    FlutterErrorDetails(exception: StateError('$what failed'), stack: stack),
  );
}
