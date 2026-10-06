// Checks the catalog source file, assets/catalog/symptoms.json. The same file
// is bundled with the app and published to Firestore by
// scripts/publish-catalog.sh, so a mistake here reaches every user.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pet_health_tracker/data/symptom_catalog.dart';

typedef Entry = Map<String, dynamic>;

List<Entry> entries(Object? list) => ((list as List?) ?? const []).cast<Entry>();

void main() {
  final catalog = jsonDecode(File('assets/catalog/symptoms.json').readAsStringSync()) as Entry;
  final symptoms = entries(catalog['symptoms']);
  List<Entry> questionsOf(Entry symptom) => entries(symptom['questions']);
  List<Entry> optionsOf(Entry question) => entries(question['options']);

  void expectUniqueKeys(List<Entry> entries, String where) {
    final keys = entries.map((entry) => entry['key']).toList();
    expect(keys.toSet(), hasLength(keys.length), reason: 'duplicate key in $where');
  }

  void expectKeyAndLabel(Entry entry, String where) {
    expect(
      entry['key'],
      isA<String>().having((key) => key.length, 'length', inInclusiveRange(1, 50)),
      reason: 'key in $where',
    );
    expect(
      entry['label'],
      isA<String>().having((label) => label, 'label', isNotEmpty),
      reason: 'label of ${entry['key']} in $where',
    );
  }

  test('the format version is one this app reads', () {
    expect(catalog['formatVersion'], 1);
  });

  test('every symptom, question and option has a key and a label', () {
    for (final symptom in symptoms) {
      expectKeyAndLabel(symptom, 'symptoms');
      for (final question in questionsOf(symptom)) {
        expectKeyAndLabel(question, symptom['key'] as String);
        for (final option in optionsOf(question)) {
          expectKeyAndLabel(option, '${symptom['key']}.${question['key']}');
        }
      }
    }
  });

  test('keys are unique', () {
    expectUniqueKeys(symptoms, 'symptoms');
    for (final symptom in symptoms) {
      expectUniqueKeys(questionsOf(symptom), symptom['key'] as String);
      for (final question in questionsOf(symptom)) {
        expectUniqueKeys(optionsOf(question), '${symptom['key']}.${question['key']}');
      }
    }
  });

  test('no catalog symptom is called other, which the app handles itself', () {
    expect(symptoms.map((symptom) => symptom['key']), isNot(contains('other')));
  });

  test('every question has a known type, and only choices have options', () {
    const choices = {QuestionType.singleChoice, QuestionType.multipleChoice};
    for (final symptom in symptoms) {
      for (final question in questionsOf(symptom)) {
        final where = '${symptom['key']}.${question['key']}';
        final type = QuestionType.values.asNameMap()[question['type']];
        expect(type, isNotNull, reason: 'type of $where');
        if (choices.contains(type)) {
          expect(optionsOf(question), isNotEmpty, reason: 'options of $where');
        } else {
          expect(question.containsKey('options'), isFalse, reason: 'options of $where');
        }
      }
    }
  });

  test('keys match test/data/catalog_keys.txt', () {
    // Logs store keys, so a key can never be removed, reused, or change its
    // type: retire it instead. New keys get a line in catalog_keys.txt, and
    // existing lines are never removed or changed.
    final keys = <String>{
      for (final symptom in symptoms) ...[
        symptom['key'] as String,
        for (final question in questionsOf(symptom)) ...[
          '${symptom['key']}.${question['key']} ${question['type']}',
          for (final option in optionsOf(question))
            '${symptom['key']}.${question['key']}.${option['key']}',
        ],
      ],
    };
    final recorded = File('test/data/catalog_keys.txt')
        .readAsLinesSync()
        .where((line) => line.isNotEmpty)
        .toSet();

    expect(recorded.difference(keys), isEmpty, reason: 'removed or changed keys');
    expect(keys.difference(recorded), isEmpty, reason: 'new keys missing from catalog_keys.txt');
  });
}
