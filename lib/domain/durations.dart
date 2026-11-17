/// [d] in whole minutes under an hour, whole hours under 2 days, otherwise
/// whole days, each rounded down: "1 minute", "5 hours", "3 days".
String gapText(Duration d) {
  if (d < const Duration(hours: 1)) return _count(d.inMinutes, 'minute');
  if (d < _twoDays) return _count(d.inHours, 'hour');
  return _count(d.inDays, 'day');
}

/// [d] as [gapText] shows it, except that from 2 days on it is in days with
/// one decimal, rounded down: "3.5 days", "3.0 days".
String averageText(Duration d) {
  if (d < _twoDays) return gapText(d);
  final tenths = d.inMicroseconds * 10 ~/ Duration.microsecondsPerDay;
  return '${tenths ~/ 10}.${tenths % 10} days';
}

const _twoDays = Duration(days: 2);

String _count(int n, String unit) => n == 1 ? '1 $unit' : '$n ${unit}s';
