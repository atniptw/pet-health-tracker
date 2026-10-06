import 'package:flutter_test/flutter_test.dart';
import 'package:pet_health_tracker/data/symptom_catalog.dart';

void main() {
  final catalog = SymptomCatalog.fromMap({
    'catalogVersion': 3,
    'formatVersion': 1,
    'symptoms': [
      {
        'key': 'vomit',
        'label': 'Vomit',
        'questions': [
          {
            'key': 'content',
            'label': 'What came up',
            'type': 'singleChoice',
            'options': [
              {'key': 'food', 'label': 'Food'},
              {'key': 'grass', 'label': 'Grass', 'retired': true},
            ],
          },
          {'key': 'blood', 'label': 'Blood', 'type': 'yesNo', 'retired': true},
          {'key': 'photo', 'label': 'Photo', 'type': 'image'},
          {'key': 'count', 'label': 'How many times', 'type': 'number'},
        ],
      },
      {'key': 'cough', 'label': 'Cough', 'retired': true, 'questions': <Object>[]},
    ],
  });

  test('reads symptoms in order with their labels', () {
    expect(catalog.symptoms.map((symptom) => symptom.key), ['vomit', 'cough']);
    expect(catalog.symptoms.map((symptom) => symptom.label), ['Vomit', 'Cough']);
  });

  test('looks up a symptom by key, including retired ones', () {
    expect(catalog.symptom('vomit')!.label, 'Vomit');
    expect(catalog.symptom('cough')!.retired, isTrue);
    expect(catalog.symptom('vomit')!.retired, isFalse);
    expect(catalog.symptom('seizure'), isNull);
  });

  test('reads questions and options, skipping question types it does not know', () {
    final questions = catalog.symptom('vomit')!.questions;

    expect(questions.map((question) => question.key), ['content', 'blood', 'count']);
    expect(questions.map((question) => question.type), [
      QuestionType.singleChoice,
      QuestionType.yesNo,
      QuestionType.number,
    ]);
    expect(questions.map((question) => question.retired), [false, true, false]);
    expect(questions.first.label, 'What came up');
    expect(questions.last.options, isEmpty);

    final options = questions.first.options;
    expect(options.map((option) => option.key), ['food', 'grass']);
    expect(options.map((option) => option.label), ['Food', 'Grass']);
    expect(options.map((option) => option.retired), [false, true]);
  });

  test('reads a symptom with no questions', () {
    final catalog = SymptomCatalog.fromMap({
      'symptoms': [
        {'key': 'cough', 'label': 'Cough'},
      ],
    });

    expect(catalog.symptom('cough')!.questions, isEmpty);
  });
}
