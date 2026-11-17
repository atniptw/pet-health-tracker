import 'package:flutter_test/flutter_test.dart';
import 'package:pet_health_tracker/domain/durations.dart';

void main() {
  const justUnder = Duration(microseconds: 1);
  const hour = Duration(hours: 1);
  const twoDays = Duration(days: 2);

  group('gapText', () {
    test('under a minute shows 0 minutes (D-022)', () {
      expect(gapText(Duration.zero), '0 minutes');
      expect(gapText(const Duration(seconds: 59)), '0 minutes');
    });

    test('minutes are singular for 1 and plural otherwise', () {
      expect(gapText(const Duration(minutes: 1)), '1 minute');
      expect(gapText(const Duration(minutes: 2)), '2 minutes');
    });

    test('whole units are rounded down (D-022)', () {
      expect(gapText(const Duration(minutes: 1, seconds: 59)), '1 minute');
      expect(gapText(const Duration(hours: 2, minutes: 59)), '2 hours');
      expect(gapText(const Duration(days: 3, hours: 23)), '3 days');
    });

    test('just under an hour is in minutes, an hour is in hours', () {
      expect(gapText(hour - justUnder), '59 minutes');
      expect(gapText(hour), '1 hour');
      expect(gapText(const Duration(hours: 2)), '2 hours');
    });

    test('just under 2 days is in hours, 2 days is in days', () {
      expect(gapText(twoDays - justUnder), '47 hours');
      expect(gapText(twoDays), '2 days');
      expect(gapText(const Duration(days: 30)), '30 days');
    });
  });

  group('averageText', () {
    test('under 2 days reads like a gap, in whole minutes or hours', () {
      expect(averageText(const Duration(seconds: 30)), '0 minutes');
      expect(averageText(const Duration(minutes: 1)), '1 minute');
      expect(averageText(hour - justUnder), '59 minutes');
      expect(averageText(hour), '1 hour');
      expect(averageText(twoDays - justUnder), '47 hours');
    });

    test('2 days and over get one decimal, also for a whole number (D-022)', () {
      expect(averageText(twoDays), '2.0 days');
      expect(averageText(const Duration(days: 3)), '3.0 days');
      expect(averageText(const Duration(days: 3, hours: 12)), '3.5 days');
      expect(averageText(const Duration(days: 12, hours: 3)), '12.1 days');
    });

    test('the decimal is rounded down (D-022)', () {
      expect(averageText(const Duration(days: 3, hours: 12) - justUnder), '3.4 days');
      expect(averageText(const Duration(days: 4) - justUnder), '3.9 days');
    });
  });
}
