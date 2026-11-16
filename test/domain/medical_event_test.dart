import 'package:flutter_test/flutter_test.dart';
import 'package:pet_health_tracker/domain/built_in_event_types.dart';
import 'package:pet_health_tracker/domain/event_type.dart';
import 'package:pet_health_tracker/domain/medical_event.dart';

void main() {
  final occurredAt = DateTime.utc(2026, 11, 14, 17, 30);
  final createdAt = DateTime.utc(2026, 11, 14, 18);
  final updatedAt = DateTime.utc(2026, 11, 14, 19);

  EventType builtIn(String id) => builtInEventTypes.firstWhere((type) => type.id == id);

  final seizure = builtIn('seizure');
  final coughing = builtIn('coughing');
  final sneezing = builtIn('sneezing');
  const custom = EventType(id: 'custom-1', name: 'Ear shaking', builtIn: false);

  MedicalEvent event({
    String id = 'event-1',
    String petId = 'pet-1',
    String typeId = 'seizure',
    DateTime? at,
    Map<String, Object> details = const {'kind': 'focal', 'duration': 90},
    String? note = 'After breakfast',
    DateTime? created,
    DateTime? updated,
  }) => MedicalEvent(
    id: id,
    petId: petId,
    typeId: typeId,
    occurredAt: at ?? occurredAt,
    details: details,
    note: note,
    createdAt: created ?? createdAt,
    updatedAt: updated ?? updatedAt,
  );

  group('MedicalEvent', () {
    test('001-FR-006: an event holds its details and note', () {
      final logged = event();
      expect(logged.id, 'event-1');
      expect(logged.petId, 'pet-1');
      expect(logged.typeId, 'seizure');
      expect(logged.occurredAt, occurredAt);
      expect(logged.details, {'kind': 'focal', 'duration': 90});
      expect(logged.note, 'After breakfast');
      expect(logged.createdAt, createdAt);
      expect(logged.updatedAt, updatedAt);
    });

    test('events with the same fields are equal', () {
      expect(event(), event());
      expect(event().hashCode, event().hashCode);
      expect(event(details: {'duration': 90, 'kind': 'focal'}), event());
      expect(event(details: {'duration': 90, 'kind': 'focal'}).hashCode, event().hashCode);
      expect(event(details: const {}, note: null), event(details: const {}, note: null));
    });

    test('events differing in any field are not equal', () {
      final base = event();
      expect(base, isNot(event(id: 'event-2')));
      expect(base, isNot(event(petId: 'pet-2')));
      expect(base, isNot(event(typeId: 'coughing')));
      expect(base, isNot(event(at: occurredAt.add(const Duration(seconds: 1)))));
      expect(base, isNot(event(details: const {'kind': 'focal'})));
      expect(base, isNot(event(details: const {'kind': 'grand_mal', 'duration': 90})));
      expect(base, isNot(event(details: const {'kind': 'focal', 'what': 90})));
      expect(base, isNot(event(details: const {})));
      expect(base, isNot(event(note: null)));
      expect(base, isNot(event(note: 'After dinner')));
      expect(base, isNot(event(created: createdAt.add(const Duration(seconds: 1)))));
      expect(base, isNot(event(updated: updatedAt.add(const Duration(seconds: 1)))));
      expect(base, isNot('event-1'));
    });
  });

  group('validDetails', () {
    test('001-FR-006: answers to the type\'s questions are accepted', () {
      const details = {'kind': 'grand_mal', 'duration': 1};
      expect(validDetails(seizure, details), details);
      expect(validDetails(seizure, const {'duration': 90}), {'duration': 90});
    });

    test('001-FR-006: details are optional', () {
      expect(validDetails(seizure, const {}), isEmpty);
      expect(validDetails(custom, const {}), isEmpty);
    });

    test('a key that is not one of the type\'s questions is refused', () {
      expect(() => validDetails(seizure, const {'leg': 'front_left'}), throwsArgumentError);
      expect(
        () => validDetails(seizure, const {'kind': 'focal', 'what': 'urine'}),
        throwsArgumentError,
      );
      expect(() => validDetails(custom, const {'duration': 90}), throwsArgumentError);
    });

    test('an answer its question does not accept is refused', () {
      expect(() => validDetails(seizure, const {'kind': 'tremor'}), throwsArgumentError);
      expect(() => validDetails(seizure, const {'kind': 90}), throwsArgumentError);
      expect(() => validDetails(seizure, const {'duration': 0}), throwsArgumentError);
      expect(() => validDetails(seizure, const {'duration': '90'}), throwsArgumentError);
    });

    test('the refusal does not repeat the answer', () {
      expect(
        () => validDetails(seizure, const {'kind': 'Shook for ages'}),
        throwsA(
          isA<ArgumentError>().having(
            (error) => error.toString(),
            'message',
            isNot(contains('Shook for ages')),
          ),
        ),
      );
    });
  });

  group('validDetailsFor', () {
    test('answers to the given questions are accepted', () {
      const details = {'kind': 'focal', 'duration': 30};
      expect(validDetailsFor(seizure.questions, details), details);
    });

    test('with no questions, any detail is refused and none is accepted', () {
      expect(validDetailsFor(const [], const {}), isEmpty);
      expect(() => validDetailsFor(const [], const {'duration': 30}), throwsArgumentError);
    });

    test('an answer its question does not accept is refused', () {
      expect(
        () => validDetailsFor(seizure.questions, const {'kind': 'tremor'}),
        throwsArgumentError,
      );
    });
  });

  group('validNote', () {
    test('001-FR-006: the note is optional; empty or spaces become null', () {
      expect(validNote(null), isNull);
      expect(validNote(''), isNull);
      expect(validNote('   \n\t '), isNull);
    });

    test('001-FR-006: the note is trimmed', () {
      expect(validNote('  After breakfast \n'), 'After breakfast');
      expect(validNote('x'), 'x');
    });

    test('a note of up to 1000 characters is kept', () {
      final longest = 'a' * 1000;
      expect(validNote(longest), longest);
      expect(validNote('  $longest  '), longest);
    });

    test('a note over 1000 characters is refused', () {
      expect(() => validNote('a' * 1001), throwsArgumentError);
    });

    test('characters are counted as the caregiver sees them', () {
      final emoji = '🐶' * 1000;
      expect(validNote(emoji), emoji);
      expect(() => validNote('🐶' * 1001), throwsArgumentError);
    });

    test('the refusal does not repeat the note', () {
      final note = 'private ${'a' * 1000}';
      expect(
        () => validNote(note),
        throwsA(
          isA<ArgumentError>().having(
            (error) => error.toString(),
            'message',
            isNot(contains('private')),
          ),
        ),
      );
    });
  });

  group('detailsKeptFor', () {
    test('001-FR-006: details the new type also asks for are kept, the rest dropped', () {
      expect(detailsKeptFor(coughing, const {'kind': 'focal', 'duration': 90}), {'duration': 90});
    });

    test('all details are kept when the type stays the same', () {
      const details = {'kind': 'focal', 'duration': 90};
      expect(detailsKeptFor(seizure, details), details);
    });

    test('every detail is dropped for a type with no questions', () {
      expect(detailsKeptFor(sneezing, const {'kind': 'focal', 'duration': 90}), isEmpty);
      expect(detailsKeptFor(custom, const {'duration': 90}), isEmpty);
      expect(detailsKeptFor(seizure, const {}), isEmpty);
    });
  });
}
