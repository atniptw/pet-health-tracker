/// The symptoms a log can be for, and the questions each one asks. Read from
/// `catalog/symptoms`, or the copy bundled with the app.
class SymptomCatalog {
  const SymptomCatalog(this.symptoms);

  /// In display order, retired ones included so they still label old logs.
  final List<CatalogSymptom> symptoms;

  factory SymptomCatalog.fromMap(Map<String, dynamic> data) {
    return SymptomCatalog([
      for (final symptom in _maps(data['symptoms'])) CatalogSymptom._fromMap(symptom),
    ]);
  }

  CatalogSymptom? symptom(String key) {
    for (final symptom in symptoms) {
      if (symptom.key == key) return symptom;
    }
    return null;
  }
}

class CatalogSymptom {
  const CatalogSymptom({
    required this.key,
    required this.label,
    this.retired = false,
    this.questions = const [],
  });

  final String key;
  final String label;

  /// No longer offered when logging, but still labels old logs.
  final bool retired;
  final List<CatalogQuestion> questions;

  factory CatalogSymptom._fromMap(Map<String, dynamic> data) {
    return CatalogSymptom(
      key: data['key'] as String,
      label: data['label'] as String,
      retired: data['retired'] == true,
      questions: [
        for (final question in _maps(data['questions']))
          // A type added after this app version shipped. Skipped, as the app
          // has no control for it.
          if (QuestionType.values.asNameMap()[question['type']] case final type?)
            CatalogQuestion._fromMap(question, type),
      ],
    );
  }
}

enum QuestionType { yesNo, singleChoice, multipleChoice, number, text }

class CatalogQuestion {
  const CatalogQuestion({
    required this.key,
    required this.label,
    required this.type,
    this.retired = false,
    this.unit,
    this.options = const [],
  });

  /// The key its answer is stored under in a log's `answers`.
  final String key;
  final String label;
  final QuestionType type;
  final bool retired;

  /// What a [QuestionType.number] answer counts, such as `seconds`.
  final String? unit;

  /// The choices, for [QuestionType.singleChoice] and
  /// [QuestionType.multipleChoice].
  final List<CatalogOption> options;

  factory CatalogQuestion._fromMap(Map<String, dynamic> data, QuestionType type) {
    return CatalogQuestion(
      key: data['key'] as String,
      label: data['label'] as String,
      type: type,
      retired: data['retired'] == true,
      unit: data['unit'] as String?,
      options: [for (final option in _maps(data['options'])) CatalogOption._fromMap(option)],
    );
  }
}

class CatalogOption {
  const CatalogOption({required this.key, required this.label, this.retired = false});

  final String key;
  final String label;
  final bool retired;

  factory CatalogOption._fromMap(Map<String, dynamic> data) {
    return CatalogOption(
      key: data['key'] as String,
      label: data['label'] as String,
      retired: data['retired'] == true,
    );
  }
}

/// A list of maps from decoded JSON or Firestore, or none when [value] is
/// missing.
Iterable<Map<String, dynamic>> _maps(Object? value) =>
    ((value as List?) ?? const []).map((item) => Map<String, dynamic>.from(item as Map));
