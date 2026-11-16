import 'package:flutter_test/flutter_test.dart';
import 'package:pet_health_tracker/domain/event_type.dart';

void main() {
  ChoiceQuestion kind() => const ChoiceQuestion(
    id: 'kind',
    label: 'Kind',
    options: [(id: 'focal', label: 'Focal'), (id: 'grand_mal', label: 'Grand mal')],
  );

  DurationQuestion lasted() => const DurationQuestion(id: 'duration', label: 'How long it lasted');

  EventType seizure() =>
      EventType(id: 'seizure', name: 'Seizure', builtIn: true, questions: [kind(), lasted()]);

  EventType custom({String name = 'Ear shaking', bool removed = false}) =>
      EventType(id: 'custom-1', name: name, builtIn: false, removed: removed);

  group('EventType', () {
    test('a built-in type has its questions and is never removed', () {
      final type = seizure();
      expect(type.id, 'seizure');
      expect(type.name, 'Seizure');
      expect(type.builtIn, isTrue);
      expect(type.questions, [kind(), lasted()]);
      expect(type.removed, isFalse);
    });

    test('a custom type has no questions and is not removed when added', () {
      final type = custom();
      expect(type.builtIn, isFalse);
      expect(type.questions, isEmpty);
      expect(type.removed, isFalse);
      expect(custom(removed: true).removed, isTrue);
    });

    test('a removed built-in type is refused', () {
      expect(
        () => EventType(id: 'seizure', name: 'Seizure', builtIn: true, removed: true),
        throwsA(isA<AssertionError>()),
      );
    });

    test('types with the same fields are equal', () {
      expect(seizure(), seizure());
      expect(seizure().hashCode, seizure().hashCode);
      expect(custom(), custom());
      expect(custom().hashCode, custom().hashCode);
    });

    test('types differing in any field are not equal', () {
      final base = seizure();
      expect(
        base,
        isNot(
          EventType(id: 'other', name: 'Seizure', builtIn: true, questions: [kind(), lasted()]),
        ),
      );
      expect(
        base,
        isNot(EventType(id: 'seizure', name: 'Fit', builtIn: true, questions: [kind(), lasted()])),
      );
      expect(
        base,
        isNot(EventType(id: 'seizure', name: 'Seizure', builtIn: true, questions: [kind()])),
      );
      expect(
        base,
        isNot(
          EventType(id: 'seizure', name: 'Seizure', builtIn: true, questions: [lasted(), kind()]),
        ),
      );
      expect(
        const EventType(id: 'x', name: 'Seizure', builtIn: true),
        isNot(const EventType(id: 'x', name: 'Seizure', builtIn: false)),
      );
      expect(custom(), isNot(custom(removed: true)));
      expect(custom(), isNot(custom(name: 'Head shaking')));
      expect(base, isNot('seizure'));
    });
  });

  group('ChoiceQuestion', () {
    test('has an id, a label and its options', () {
      final question = kind();
      expect(question.id, 'kind');
      expect(question.label, 'Kind');
      expect(question.options, [
        (id: 'focal', label: 'Focal'),
        (id: 'grand_mal', label: 'Grand mal'),
      ]);
    });

    test('accepts the id of each of its options', () {
      expect(kind().accepts('focal'), isTrue);
      expect(kind().accepts('grand_mal'), isTrue);
    });

    test('refuses an unknown option id, a label and answers that are not strings', () {
      expect(kind().accepts('tonic'), isFalse);
      expect(kind().accepts('Grand mal'), isFalse);
      expect(kind().accepts(''), isFalse);
      expect(kind().accepts(1), isFalse);
      expect(kind().accepts(true), isFalse);
    });

    test('describe returns the option label', () {
      expect(kind().describe('focal'), 'Focal');
      expect(kind().describe('grand_mal'), 'Grand mal');
    });

    test('describe throws for an answer it does not accept', () {
      expect(() => kind().describe('tonic'), throwsArgumentError);
      expect(() => kind().describe(1), throwsArgumentError);
    });

    test('questions with the same fields are equal', () {
      expect(kind(), kind());
      expect(kind().hashCode, kind().hashCode);
    });

    test('questions differing in any field are not equal', () {
      const options = [(id: 'focal', label: 'Focal'), (id: 'grand_mal', label: 'Grand mal')];
      expect(kind(), isNot(const ChoiceQuestion(id: 'type', label: 'Kind', options: options)));
      expect(kind(), isNot(const ChoiceQuestion(id: 'kind', label: 'Type', options: options)));
      expect(
        kind(),
        isNot(
          const ChoiceQuestion(id: 'kind', label: 'Kind', options: [(id: 'focal', label: 'Focal')]),
        ),
      );
      expect(
        kind(),
        isNot(
          const ChoiceQuestion(
            id: 'kind',
            label: 'Kind',
            options: [(id: 'focal', label: 'Focal'), (id: 'grand_mal', label: 'Grand-mal')],
          ),
        ),
      );
      expect(kind(), isNot(const DurationQuestion(id: 'kind', label: 'Kind')));
    });
  });

  group('DurationQuestion', () {
    test('has an id and a label', () {
      expect(lasted().id, 'duration');
      expect(lasted().label, 'How long it lasted');
    });

    test('accepts whole seconds from 1', () {
      expect(lasted().accepts(1), isTrue);
      expect(lasted().accepts(150), isTrue);
    });

    test('refuses 0, negative seconds and answers that are not ints', () {
      expect(lasted().accepts(0), isFalse);
      expect(lasted().accepts(-1), isFalse);
      expect(lasted().accepts(1.5), isFalse);
      expect(lasted().accepts('90'), isFalse);
      expect(lasted().accepts(true), isFalse);
    });

    test('describe writes minutes and seconds', () {
      expect(lasted().describe(150), '2 min 30 s');
      expect(lasted().describe(61), '1 min 1 s');
    });

    test('describe writes seconds only under a minute', () {
      expect(lasted().describe(45), '45 s');
      expect(lasted().describe(1), '1 s');
      expect(lasted().describe(59), '59 s');
    });

    test('describe writes minutes only for whole minutes', () {
      expect(lasted().describe(180), '3 min');
      expect(lasted().describe(60), '1 min');
    });

    test('describe throws for an answer it does not accept', () {
      expect(() => lasted().describe(0), throwsArgumentError);
      expect(() => lasted().describe('90'), throwsArgumentError);
    });

    test('questions with the same fields are equal', () {
      expect(lasted(), lasted());
      expect(lasted().hashCode, lasted().hashCode);
    });

    test('questions differing in any field are not equal', () {
      expect(lasted(), isNot(const DurationQuestion(id: 'length', label: 'How long it lasted')));
      expect(lasted(), isNot(const DurationQuestion(id: 'duration', label: 'Duration')));
    });
  });

  group('matchKey', () {
    test('001-EC-07: names differing only in capitalization have the same key', () {
      expect(matchKey('Vomiting'), matchKey('vomiting'));
      expect(matchKey('VOMITING'), 'vomiting');
      expect(matchKey('Ear Shaking'), matchKey('ear shaking'));
    });

    test('001-EC-07: trims and collapses inner runs of spaces to one', () {
      expect(matchKey('  Ear   SHAKING '), 'ear shaking');
      expect(matchKey('ear shaking'), 'ear shaking');
    });

    test('different words have different keys', () {
      expect(matchKey('Ear shaking'), isNot(matchKey('Earshaking')));
    });
  });

  group('validTypeName', () {
    test('returns the name as typed, trimmed and inner spaces collapsed', () {
      expect(validTypeName('  Ear   SHAKING '), 'Ear SHAKING');
      expect(validTypeName('Ear shaking'), 'Ear shaking');
    });

    test('a single character is allowed', () {
      expect(validTypeName('a'), 'a');
      expect(validTypeName(' a '), 'a');
    });

    test('a name empty after trimming is refused', () {
      expect(() => validTypeName(''), throwsArgumentError);
      expect(() => validTypeName('    '), throwsArgumentError);
    });

    test('40 characters are allowed, 41 are refused', () {
      expect(validTypeName('a' * 40), 'a' * 40);
      expect(() => validTypeName('a' * 41), throwsArgumentError);
    });

    test('counts the length after trimming and collapsing spaces', () {
      final forty = '${'a' * 20} ${'b' * 19}';
      expect(validTypeName('  ${'a' * 20}     ${'b' * 19}  '), forty);
      expect(() => validTypeName('${'a' * 20}  ${'b' * 20}'), throwsArgumentError);
    });

    test('counts each emoji as one character', () {
      final name = '🐶' * 40;
      expect(validTypeName(name), name);
      expect(() => validTypeName('🐶' * 41), throwsArgumentError);
    });
  });
}
