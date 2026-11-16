import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_health_tracker/domain/built_in_event_types.dart';
import 'package:pet_health_tracker/domain/event_type.dart';
import 'package:pet_health_tracker/domain/medical_event.dart';
import 'package:pet_health_tracker/ui/common/detail_questions.dart';

import '../../support/screen_checks.dart';

EventType builtIn(String id) => builtInEventTypes.firstWhere((type) => type.id == id);

/// The questions of [type], keeping each reported map in the returned list.
Future<List<Map<String, Object>>> pumpQuestions(WidgetTester tester, EventType type) async {
  final reported = <Map<String, Object>>[];
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: DetailQuestions(questions: type.questions, onChanged: reported.add),
        ),
      ),
    ),
  );
  return reported;
}

Finder chip(String label) => find.widgetWithText(ChoiceChip, label);

bool selected(WidgetTester tester, String label) => tester.widget<ChoiceChip>(chip(label)).selected;

Future<void> tap(WidgetTester tester, String label) async {
  await tester.ensureVisible(chip(label));
  await tester.tap(chip(label));
  await tester.pump();
}

void main() {
  testWidgets('001-US1-S7: a choice question is a row of chips, none picked', (tester) async {
    final reported = await pumpQuestions(tester, builtIn('vomiting'));

    expect(find.text('What came up'), findsOneWidget);
    for (final label in [
      'Food',
      'Yellow liquid or bile',
      'Foam',
      'Hairball',
      'Blood',
      'Something else',
    ]) {
      expect(chip(label), findsOneWidget);
      expect(selected(tester, label), isFalse);
    }
    expect(reported, isEmpty);
  });

  testWidgets('001-US1-S7: tapping a chip picks it and reports its option id', (tester) async {
    final reported = await pumpQuestions(tester, builtIn('vomiting'));

    await tap(tester, 'Yellow liquid or bile');

    expect(selected(tester, 'Yellow liquid or bile'), isTrue);
    expect(reported.last, {'what_came_up': 'bile'});
  });

  testWidgets('001-US1-S7: tapping another chip replaces the pick', (tester) async {
    final reported = await pumpQuestions(tester, builtIn('vomiting'));
    await tap(tester, 'Food');

    await tap(tester, 'Foam');

    expect(selected(tester, 'Food'), isFalse);
    expect(selected(tester, 'Foam'), isTrue);
    expect(reported.last, {'what_came_up': 'foam'});
  });

  testWidgets('001-US1-S7: tapping the picked chip again clears it (skipped)', (tester) async {
    final reported = await pumpQuestions(tester, builtIn('vomiting'));
    await tap(tester, 'Food');

    await tap(tester, 'Food');

    expect(selected(tester, 'Food'), isFalse);
    expect(reported.last, isEmpty);
  });

  testWidgets('001-FR-006: each question answered or skipped on its own', (tester) async {
    final reported = await pumpQuestions(tester, builtIn('diarrhea'));

    await tap(tester, 'Watery');
    expect(reported.last, {'consistency': 'watery'});

    await tap(tester, 'Yes');
    expect(reported.last, {'consistency': 'watery', 'blood_seen': 'yes'});

    await tap(tester, 'Watery');
    expect(reported.last, {'blood_seen': 'yes'});
  });

  testWidgets('001-US1-S7: a duration question is the duration field', (tester) async {
    final reported = await pumpQuestions(tester, builtIn('seizure'));

    expect(find.text('Kind'), findsOneWidget);
    expect(find.text('How long it lasted'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, 'Minutes'), '2');
    await tester.pump();

    expect(reported.last, {'duration': 120});
  });

  testWidgets('001-US1-S7: seizure with kind and duration, then duration cleared', (tester) async {
    final reported = await pumpQuestions(tester, builtIn('seizure'));
    final type = builtIn('seizure');

    await tap(tester, 'Grand mal');
    await tester.enterText(find.widgetWithText(TextField, 'Seconds'), '45');
    await tester.pump();
    expect(reported.last, {'kind': 'grand_mal', 'duration': 45});
    expect(validDetails(type, reported.last), reported.last);

    await tester.enterText(find.widgetWithText(TextField, 'Seconds'), '');
    await tester.pump();
    expect(reported.last, {'kind': 'grand_mal'});
  });

  testWidgets('001-FR-006: every built-in type reports details validDetails accepts', (
    tester,
  ) async {
    for (final type in builtInEventTypes) {
      await tester.pumpWidget(const SizedBox());
      final reported = await pumpQuestions(tester, type);
      for (final question in type.questions) {
        switch (question) {
          case ChoiceQuestion(:final options):
            await tap(tester, options.last.label);
          case DurationQuestion():
            await tester.enterText(find.widgetWithText(TextField, 'Minutes'), '1');
            await tester.pump();
        }
      }
      if (type.questions.isEmpty) {
        expect(reported, isEmpty, reason: type.name);
      } else {
        expect(reported.last.keys, unorderedEquals(type.questions.map((q) => q.id)));
        expect(validDetails(type, reported.last), reported.last, reason: type.name);
      }
    }
  });

  testWidgets('001-FR-006: a type with no questions shows nothing', (tester) async {
    final reported = await pumpQuestions(tester, builtIn('sneezing'));

    expect(find.byType(ChoiceChip), findsNothing);
    expect(find.byType(TextField), findsNothing);
    expect(reported, isEmpty);
  });

  testWidgets('001-US1-S7: the questions are accessible', (tester) async {
    await pumpQuestions(tester, builtIn('seizure'));

    await expectAccessible(tester);
  });
}
