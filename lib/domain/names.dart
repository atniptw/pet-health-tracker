import 'package:characters/characters.dart';

/// The longest name, in user-perceived characters.
const maxNameLength = 40;

/// [name] unchanged; throws [ArgumentError] unless it is 1–40 characters.
String checkedNameLength(String name) {
  final length = name.characters.length;
  if (length < 1 || length > maxNameLength) {
    throw ArgumentError('Must be 1–$maxNameLength characters', 'name');
  }
  return name;
}

/// Orders items by name ignoring case (`toLowerCase()`), then by id, so items
/// with the same name keep their places.
Comparator<T> byName<T>({required String Function(T) name, required String Function(T) id}) {
  return (a, b) {
    final byName = name(a).toLowerCase().compareTo(name(b).toLowerCase());
    return byName != 0 ? byName : id(a).compareTo(id(b));
  };
}
