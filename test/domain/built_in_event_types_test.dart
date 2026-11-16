import 'package:flutter_test/flutter_test.dart';
import 'package:pet_health_tracker/domain/built_in_event_types.dart';
import 'package:pet_health_tracker/domain/event_type.dart';

void main() {
  const lasted = DurationQuestion(id: 'duration', label: 'How long it lasted');

  ChoiceQuestion choice(String id, String label, List<(String, String)> options) => ChoiceQuestion(
    id: id,
    label: label,
    options: [for (final (id, label) in options) (id: id, label: label)],
  );

  EventType builtIn(String id, String name, [List<DetailQuestion> questions = const []]) =>
      EventType(id: id, name: name, builtIn: true, questions: questions);

  final expected = [
    builtIn('vomiting', 'Vomiting', [
      choice('what_came_up', 'What came up', [
        ('food', 'Food'),
        ('bile', 'Yellow liquid or bile'),
        ('foam', 'Foam'),
        ('hairball', 'Hairball'),
        ('blood', 'Blood'),
        ('something_else', 'Something else'),
      ]),
    ]),
    builtIn('diarrhea', 'Diarrhea', [
      choice('consistency', 'Consistency', [('soft', 'Soft'), ('watery', 'Watery')]),
      choice('blood_seen', 'Blood seen', [('yes', 'Yes'), ('no', 'No')]),
    ]),
    builtIn('seizure', 'Seizure', [
      choice('kind', 'Kind', [('focal', 'Focal'), ('grand_mal', 'Grand mal')]),
      lasted,
    ]),
    builtIn('coughing', 'Coughing', [lasted]),
    builtIn('sneezing', 'Sneezing'),
    builtIn('limping', 'Limping', [
      choice('leg', 'Which leg', [
        ('front_left', 'Front left'),
        ('front_right', 'Front right'),
        ('back_left', 'Back left'),
        ('back_right', 'Back right'),
      ]),
    ]),
    builtIn('not_eating', 'Not eating', [
      choice('meals_missed', 'Meals missed', [
        ('one', '1'),
        ('two', '2'),
        ('three_or_more', '3 or more'),
      ]),
    ]),
    builtIn('lethargy', 'Lethargy'),
    builtIn('scratching', 'Scratching'),
    builtIn('accident', 'Accident in the house', [
      choice('what', 'What', [('urine', 'Urine'), ('stool', 'Stool'), ('both', 'Both')]),
    ]),
    builtIn('wound', 'Wound'),
  ];

  bool allUnique<T>(Iterable<T> values) => values.toSet().length == values.length;

  test('001-FR-002: the common pet medical events, in order', () {
    expect(builtInEventTypes.map((type) => type.id), [
      'vomiting',
      'diarrhea',
      'seizure',
      'coughing',
      'sneezing',
      'limping',
      'not_eating',
      'lethargy',
      'scratching',
      'accident',
      'wound',
    ]);
    expect(builtInEventTypes.map((type) => type.name), [
      'Vomiting',
      'Diarrhea',
      'Seizure',
      'Coughing',
      'Sneezing',
      'Limping',
      'Not eating',
      'Lethargy',
      'Scratching',
      'Accident in the house',
      'Wound',
    ]);
  });

  test('001-FR-002: each type has exactly its detail questions and options', () {
    expect(builtInEventTypes, expected);
    for (final type in builtInEventTypes) {
      expect(type.builtIn, isTrue, reason: type.id);
      expect(type.removed, isFalse, reason: type.id);
    }
  });

  test('001-FR-002: type ids and match keys are unique', () {
    expect(allUnique(builtInEventTypes.map((type) => type.id)), isTrue);
    expect(allUnique(builtInEventTypes.map((type) => matchKey(type.name))), isTrue);
  });

  test('001-FR-002: question ids are unique within each type', () {
    for (final type in builtInEventTypes) {
      expect(allUnique(type.questions.map((q) => q.id)), isTrue, reason: type.id);
    }
  });

  test('001-FR-002: option ids are unique within each choice question', () {
    for (final type in builtInEventTypes) {
      for (final question in type.questions.whereType<ChoiceQuestion>()) {
        expect(
          allUnique(question.options.map((option) => option.id)),
          isTrue,
          reason: '${type.id}.${question.id}',
        );
      }
    }
  });

  test('001-FR-002: the list cannot be changed at run time', () {
    expect(() => builtInEventTypes.add(builtIn('x', 'X')), throwsUnsupportedError);
  });
}
