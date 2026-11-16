import 'names.dart';

/// A kind of event the caregiver logs: a built-in type or one typed in their
/// own words.
class EventType {
  const EventType({
    required this.id,
    required this.name,
    required this.builtIn,
    this.questions = const [],
    this.removed = false,
  }) : assert(!builtIn || !removed, 'Built-in types are never removed');

  final String id;
  final String name;
  final bool builtIn;

  /// The optional detail questions; empty for custom types.
  final List<DetailQuestion> questions;

  /// Whether a custom type has been removed from the list.
  final bool removed;

  @override
  bool operator ==(Object other) =>
      other is EventType &&
      other.id == id &&
      other.name == name &&
      other.builtIn == builtIn &&
      _listEquals(other.questions, questions) &&
      other.removed == removed;

  @override
  int get hashCode => Object.hash(id, name, builtIn, Object.hashAll(questions), removed);
}

/// A question about an event's details; each kind owns its answer rules.
sealed class DetailQuestion {
  const DetailQuestion({required this.id, required this.label});

  /// Unique within its type; never changed or reused.
  final String id;

  /// What the caregiver is shown.
  final String label;

  /// Whether [answer] is a valid stored answer to this question.
  bool accepts(Object answer);

  /// [answer] written out for the history; throws [ArgumentError] unless
  /// [accepts] is true for it.
  String describe(Object answer);
}

/// Pick one of [options]; the answer is the option's id.
final class ChoiceQuestion extends DetailQuestion {
  const ChoiceQuestion({required super.id, required super.label, required this.options});

  /// Option ids are never changed or reused; labels can change.
  final List<({String id, String label})> options;

  @override
  bool accepts(Object answer) => options.any((option) => option.id == answer);

  @override
  String describe(Object answer) {
    if (!accepts(answer)) throw ArgumentError('Not one of the options', 'answer');
    return options.firstWhere((option) => option.id == answer).label;
  }

  @override
  bool operator ==(Object other) =>
      other is ChoiceQuestion &&
      other.id == id &&
      other.label == label &&
      _listEquals(other.options, options);

  @override
  int get hashCode => Object.hash(id, label, Object.hashAll(options));
}

/// How long something lasted; the answer is whole seconds, at least 1.
final class DurationQuestion extends DetailQuestion {
  const DurationQuestion({required super.id, required super.label});

  @override
  bool accepts(Object answer) => answer is int && answer >= 1;

  @override
  String describe(Object answer) {
    if (!accepts(answer)) {
      throw ArgumentError('Must be whole seconds, at least 1', 'answer');
    }
    final total = answer as int;
    final minutes = total ~/ 60;
    final seconds = total % 60;
    if (minutes == 0) return '$seconds s';
    if (seconds == 0) return '$minutes min';
    return '$minutes min $seconds s';
  }

  @override
  bool operator ==(Object other) =>
      other is DurationQuestion && other.id == id && other.label == label;

  @override
  int get hashCode => Object.hash(id, label);
}

final _spaceRuns = RegExp(' {2,}');

String _collapsed(String typed) => typed.trim().replaceAll(_spaceRuns, ' ');

/// The key type names are compared by: trimmed, inner runs of spaces
/// collapsed to one, lower-cased.
String matchKey(String typed) => _collapsed(typed).toLowerCase();

/// [typed] trimmed with inner runs of spaces collapsed; throws
/// [ArgumentError] unless it is 1–40 characters.
String validTypeName(String typed) => checkedNameLength(_collapsed(typed));

bool _listEquals<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
