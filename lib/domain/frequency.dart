import 'medical_event.dart';

/// A rolling window of time ending now, over which a type's events are counted.
enum Period {
  last30Days,
  last90Days,
  last12Months,
  allTime;

  static const defaultPeriod = last90Days;

  /// The earliest moment in the window ending at [now], or null for all time.
  DateTime? start(DateTime now) => switch (this) {
    last30Days => now.subtract(const Duration(days: 30)),
    last90Days => now.subtract(const Duration(days: 90)),
    last12Months => now.copyWith(year: now.year - 1),
    allTime => null,
  };
}

/// How often one event type happened for a pet over a period.
class TypeSummary {
  const TypeSummary({
    required this.typeId,
    required this.count,
    this.averageGap,
    required this.lastAt,
  });

  final String typeId;
  final int count;

  /// The average time between the events, or null with fewer than two.
  final Duration? averageGap;

  /// When the newest event happened, in UTC.
  final DateTime lastAt;

  @override
  bool operator ==(Object other) =>
      other is TypeSummary &&
      other.typeId == typeId &&
      other.count == count &&
      other.averageGap == averageGap &&
      other.lastAt == lastAt;

  @override
  int get hashCode => Object.hash(typeId, count, averageGap, lastAt);
}

/// The time from the latest event of [e]'s type in [petEvents] that happened
/// before [e], or null when there is none.
Duration? timeSincePrevious(MedicalEvent e, List<MedicalEvent> petEvents) {
  DateTime? previous;
  for (final other in petEvents) {
    final at = other.occurredAt;
    if (other.typeId != e.typeId || !at.isBefore(e.occurredAt)) continue;
    if (previous == null || at.isAfter(previous)) previous = at;
  }
  return previous == null ? null : e.occurredAt.difference(previous);
}

/// A summary for each type with an event in [p], the most recently happened
/// type first.
List<TypeSummary> summaries(List<MedicalEvent> petEvents, Period p, DateTime now) {
  final start = p.start(now);
  final byType = <String, List<DateTime>>{};
  for (final e in petEvents) {
    if (start != null && e.occurredAt.isBefore(start)) continue;
    byType.putIfAbsent(e.typeId, () => []).add(e.occurredAt);
  }
  return [for (final MapEntry(:key, :value) in byType.entries) _summary(key, value)]
    ..sort((a, b) => b.lastAt.compareTo(a.lastAt));
}

TypeSummary _summary(String typeId, List<DateTime> times) {
  times.sort();
  final count = times.length;
  return TypeSummary(
    typeId: typeId,
    count: count,
    averageGap: count < 2 ? null : times.last.difference(times.first) ~/ (count - 1),
    lastAt: times.last,
  );
}
