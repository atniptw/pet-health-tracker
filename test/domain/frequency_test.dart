import 'package:flutter_test/flutter_test.dart';
import 'package:pet_health_tracker/domain/frequency.dart';
import 'package:pet_health_tracker/domain/medical_event.dart';

void main() {
  final now = DateTime.utc(2026, 11, 17, 15, 30);

  MedicalEvent event(String id, String typeId, DateTime at) => MedicalEvent(
    id: id,
    petId: 'pet-1',
    typeId: typeId,
    occurredAt: at,
    createdAt: at,
    updatedAt: at,
  );

  DateTime daysAgo(num days) => now.subtract(Duration(minutes: (days * 24 * 60).round()));

  group('Period', () {
    test(
      '001-FR-010: the periods are 30 days, 90 days, 12 months and all time, 90 days by default',
      () {
        expect(Period.values, [
          Period.last30Days,
          Period.last90Days,
          Period.last12Months,
          Period.allTime,
        ]);
        expect(Period.defaultPeriod, Period.last90Days);
      },
    );

    test('001-FR-010: each period is a rolling window ending now', () {
      expect(Period.last30Days.start(now), DateTime.utc(2026, 10, 18, 15, 30));
      expect(Period.last90Days.start(now), DateTime.utc(2026, 8, 19, 15, 30));
      expect(Period.last12Months.start(now), DateTime.utc(2025, 11, 17, 15, 30));
      expect(Period.allTime.start(now), isNull);
    });

    test('001-FR-010: 12 months is the same date and time one year back, across a Feb 29', () {
      final afterLeapDay = DateTime.utc(2028, 3, 1, 15, 30);
      final start = DateTime.utc(2027, 3, 1, 15, 30);
      expect(Period.last12Months.start(afterLeapDay), start);
      final events = [
        event('e1', 'vomiting', start),
        event('e2', 'vomiting', DateTime.utc(2028, 2, 29, 9)),
      ];
      expect(summaries(events, Period.last12Months, afterLeapDay).single.count, 2);
    });
  });

  group('timeSincePrevious', () {
    final first = event('e1', 'vomiting', daysAgo(10));
    final second = event('e2', 'vomiting', daysAgo(7));
    final cough = event('e3', 'coughing', daysAgo(5));
    final third = event('e4', 'vomiting', daysAgo(2));
    final petEvents = [third, cough, first, second];

    test('001-FR-009: an event shows the gap to the latest earlier event of its type', () {
      expect(timeSincePrevious(second, petEvents), const Duration(days: 3));
      expect(timeSincePrevious(third, petEvents), const Duration(days: 5));
    });

    test(
      '001-US2-S2: each event after the first of a type shows the time since the previous one',
      () {
        expect(
          [
            for (final e in [first, second, third]) timeSincePrevious(e, petEvents),
          ],
          [null, const Duration(days: 3), const Duration(days: 5)],
        );
      },
    );

    test('001-US2-S4: the only event of a type has no time since a previous one', () {
      expect(timeSincePrevious(cough, petEvents), isNull);
      expect(timeSincePrevious(first, petEvents), isNull);
    });

    test('the gap looks back over the whole history, not a period', () {
      final old = event('e0', 'seizure', daysAgo(400));
      final recent = event('e9', 'seizure', daysAgo(1));
      expect(timeSincePrevious(recent, [old, recent]), const Duration(days: 399));
    });
  });

  group('summaries', () {
    test(
      '001-US2-S3: per type, the count, the average time between and the last one, over the period',
      () {
        final events = [
          event('e1', 'vomiting', daysAgo(10)),
          event('e2', 'vomiting', daysAgo(7)),
          event('e3', 'vomiting', daysAgo(3)),
          event('e4', 'coughing', daysAgo(1)),
          event('e5', 'coughing', daysAgo(2)),
        ];
        final result = summaries(events, Period.last30Days, now);
        expect(result, [
          TypeSummary(
            typeId: 'coughing',
            count: 2,
            averageGap: const Duration(days: 1),
            lastAt: daysAgo(1),
          ),
          TypeSummary(
            typeId: 'vomiting',
            count: 3,
            averageGap: const Duration(days: 3, hours: 12),
            lastAt: daysAgo(3),
          ),
        ]);
      },
    );

    test('001-US2-S4: one event of a type shows its count and no average', () {
      final result = summaries([event('e1', 'seizure', daysAgo(4))], Period.last90Days, now);
      expect(result, [
        TypeSummary(typeId: 'seizure', count: 1, averageGap: null, lastAt: daysAgo(4)),
      ]);
    });

    test('001-FR-010: an event on the start of the period counts, one just before does not', () {
      final onStart = event('e1', 'vomiting', DateTime.utc(2026, 10, 18, 15, 30));
      final justBefore = event('e0', 'vomiting', DateTime.utc(2026, 10, 18, 15, 29, 59));
      final latest = event('e2', 'vomiting', daysAgo(0));
      final result = summaries([justBefore, onStart, latest], Period.last30Days, now);
      expect(result.single.count, 2);
      expect(result.single.averageGap, const Duration(days: 30));
    });

    test('001-FR-010: each period counts only its own events', () {
      final events = [
        event('e1', 'vomiting', daysAgo(1)),
        event('e2', 'vomiting', daysAgo(31)),
        event('e3', 'vomiting', daysAgo(91)),
        event('e4', 'vomiting', daysAgo(366)),
      ];
      int count(Period p) => summaries(events, p, now).single.count;
      expect(count(Period.last30Days), 1);
      expect(count(Period.last90Days), 2);
      expect(count(Period.last12Months), 3);
      expect(count(Period.allTime), 4);
      expect(
        summaries(events, Period.allTime, now).single.averageGap,
        const Duration(days: 365) ~/ 3,
      );
    });

    test('a type with no events in the period has no summary', () {
      final events = [event('e1', 'vomiting', daysAgo(1)), event('e2', 'seizure', daysAgo(40))];
      expect(summaries(events, Period.last30Days, now).map((s) => s.typeId), ['vomiting']);
      expect(summaries(const [], Period.allTime, now), isEmpty);
    });

    test('summaries with the same fields are equal', () {
      final a = TypeSummary(
        typeId: 't',
        count: 2,
        averageGap: const Duration(hours: 1),
        lastAt: now,
      );
      expect(
        a,
        TypeSummary(typeId: 't', count: 2, averageGap: const Duration(hours: 1), lastAt: now),
      );
      expect(
        a.hashCode,
        TypeSummary(
          typeId: 't',
          count: 2,
          averageGap: const Duration(hours: 1),
          lastAt: now,
        ).hashCode,
      );
      expect(
        a,
        isNot(
          TypeSummary(typeId: 'u', count: 2, averageGap: const Duration(hours: 1), lastAt: now),
        ),
      );
      expect(
        a,
        isNot(
          TypeSummary(typeId: 't', count: 3, averageGap: const Duration(hours: 1), lastAt: now),
        ),
      );
      expect(a, isNot(TypeSummary(typeId: 't', count: 2, averageGap: null, lastAt: now)));
      expect(
        a,
        isNot(
          TypeSummary(
            typeId: 't',
            count: 2,
            averageGap: const Duration(hours: 1),
            lastAt: daysAgo(1),
          ),
        ),
      );
    });
  });
}
