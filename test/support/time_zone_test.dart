import 'package:flutter_test/flutter_test.dart';

/// Tests run in one time zone everywhere, so dates and day boundaries behave
/// the same on a laptop and in CI. scripts/test.sh sets it.
void main() {
  test('runs in the America/Chicago time zone', () {
    expect(
      DateTime(2026, 1, 1).timeZoneOffset,
      const Duration(hours: -6),
      reason: 'Run tests with ./scripts/test.sh, which sets the time zone',
    );
  });
}
