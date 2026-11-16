import 'package:characters/characters.dart';

/// The longest name, in user-perceived characters.
const _maxNameLength = 40;

/// [name] unchanged; throws [ArgumentError] unless it is 1–40 characters.
String checkedNameLength(String name) {
  final length = name.characters.length;
  if (length < 1 || length > _maxNameLength) {
    throw ArgumentError('Must be 1–$_maxNameLength characters', 'name');
  }
  return name;
}
