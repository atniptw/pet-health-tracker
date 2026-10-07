import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_health_tracker/data/symptom_catalog.dart';
import 'package:pet_health_tracker/features/symptoms/log_summary.dart';

void main() {
  group('formatRecentTime', () {
    final now = DateTime(2026, 10, 7, 18);

    Future<String> format(WidgetTester tester, DateTime occurredAt) async {
      late String result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              result = formatRecentTime(context, occurredAt, now: now);
              return const SizedBox();
            },
          ),
        ),
      );
      return result;
    }

    testWidgets('today shows the time of day', (tester) async {
      expect(await format(tester, DateTime(2026, 10, 7, 14, 5)), '2:05 PM');
    });

    testWidgets('yesterday shows "Yesterday"', (tester) async {
      expect(await format(tester, DateTime(2026, 10, 6, 23, 59)), 'Yesterday');
    });

    testWidgets('older days this year show the weekday and date', (tester) async {
      expect(await format(tester, DateTime(2026, 10, 5, 9)), 'Mon 5 Oct');
    });

    testWidgets('days in another year end with the year', (tester) async {
      expect(await format(tester, DateTime(2025, 12, 31, 9)), 'Wed 31 Dec 2025');
    });
  });

  group('summarizeAnswers', () {
    const seizure = CatalogSymptom(
      key: 'seizure',
      label: 'Seizure',
      questions: [
        CatalogQuestion(
          key: 'durationSeconds',
          label: 'Duration',
          type: QuestionType.number,
          unit: 'seconds',
        ),
        CatalogQuestion(key: 'count', label: 'Count', type: QuestionType.number),
        CatalogQuestion(
          key: 'type',
          label: 'Type',
          type: QuestionType.singleChoice,
          options: [CatalogOption(key: 'focal', label: 'Focal')],
        ),
        CatalogQuestion(
          key: 'signs',
          label: 'Signs',
          type: QuestionType.multipleChoice,
          options: [
            CatalogOption(key: 'drool', label: 'Drooling'),
            CatalogOption(key: 'paddle', label: 'Paddling'),
          ],
        ),
        CatalogQuestion(key: 'urinated', label: 'Urinated', type: QuestionType.yesNo),
        CatalogQuestion(key: 'foaming', label: 'Foaming', type: QuestionType.yesNo),
        CatalogQuestion(key: 'trigger', label: 'Trigger', type: QuestionType.text),
      ],
    );

    test("joins the answers in the catalog's order", () {
      expect(
        summarizeAnswers(seizure, {
          'trigger': 'Thunder',
          'urinated': true,
          'foaming': false,
          'signs': ['drool', 'paddle'],
          'type': 'focal',
          'count': 2,
          'durationSeconds': 90,
        }),
        '90 seconds · 2 · Focal · Drooling, Paddling · Urinated · Thunder',
      );
    });

    test('shows option keys the catalog lacks, and skips unknown questions', () {
      expect(summarizeAnswers(seizure, {'type': 'tonic', 'mood': 'calm'}), 'tonic');
    });

    test('is empty with no answers', () {
      expect(summarizeAnswers(seizure, {}), '');
    });
  });
}
