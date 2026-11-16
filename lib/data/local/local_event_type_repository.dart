import 'package:sqflite/sqflite.dart';

import '../../domain/built_in_event_types.dart';
import '../../domain/event_type.dart';
import '../../domain/names.dart';
import '../repositories.dart';
import 'change_signal.dart';

/// [EventTypeRepository] on the app's SQLite database: built-in types from
/// code, custom types from the `event_types` table, kept in memory so
/// [match] answers synchronously.
class LocalEventTypeRepository implements EventTypeRepository {
  LocalEventTypeRepository._(this._db, this._ids);

  /// Opens the repository with the custom types already loaded.
  static Future<LocalEventTypeRepository> open(Database db, IdGenerator ids) async {
    final repo = LocalEventTypeRepository._(db, ids);
    await repo._load();
    return repo;
  }

  final Database _db;
  final IdGenerator _ids;

  final _changes = ChangeSignal();

  /// Every custom type, removed or not, by name.
  List<EventType> _custom = const [];

  static final _compareByName = byName<EventType>(name: (type) => type.name, id: (type) => type.id);

  @override
  Stream<List<EventType>> watchOffered() =>
      _changes.watch(() async => [...builtInEventTypes, ..._offeredCustom()]);

  @override
  Stream<List<EventType>> watchCustom() => _changes.watch(() async => _offeredCustom());

  @override
  Future<EventType> byId(String id) async {
    for (final type in builtInEventTypes) {
      if (type.id == id) return type;
    }
    final rows = await _db.query('event_types', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) throw StateError('No event type with this id');
    return _fromRow(rows.single);
  }

  @override
  EventType? match(String typed) {
    final key = matchKey(typed);
    return _withKey(builtInEventTypes, key) ?? _withKey(_custom, key);
  }

  @override
  Future<void> remove(String customId) async {
    await _db.update('event_types', {'removed': 1}, where: 'id = ?', whereArgs: [customId]);
    await notifyChanged();
  }

  /// The id of the type [choice] names, inside the caller's [txn]: a typed
  /// name matching a type (research §7) uses it, un-removing a removed custom
  /// type; any other name is inserted as a new custom type.
  ///
  /// Throws [ArgumentError] for a new name [validTypeName] refuses. Doesn't
  /// notify; call [notifyChanged] once [txn] has committed.
  Future<String> resolveForSave(Transaction txn, TypeChoice choice) async {
    switch (choice) {
      case ExistingType(:final typeId):
        return typeId;
      case NewTypeName(:final name):
        return _resolveName(txn, name);
    }
  }

  /// Reloads the custom types and makes every open stream emit again.
  Future<void> notifyChanged() async {
    await _load();
    _changes.notify();
  }

  Future<String> _resolveName(Transaction txn, String typed) async {
    final name = validTypeName(typed);
    final key = matchKey(name);
    final builtIn = _withKey(builtInEventTypes, key);
    if (builtIn != null) return builtIn.id;
    final rows = await txn.query('event_types', where: 'match_key = ?', whereArgs: [key]);
    if (rows.isNotEmpty) {
      final id = rows.single['id']! as String;
      await txn.update('event_types', {'removed': 0}, where: 'id = ?', whereArgs: [id]);
      return id;
    }
    final id = _ids();
    await txn.insert('event_types', {'id': id, 'name': name, 'match_key': key, 'removed': 0});
    return id;
  }

  Future<void> _load() async {
    final rows = await _db.query('event_types');
    _custom = rows.map(_fromRow).toList()..sort(_compareByName);
  }

  static EventType? _withKey(Iterable<EventType> types, String key) =>
      types.where((type) => matchKey(type.name) == key).firstOrNull;

  List<EventType> _offeredCustom() => [
    for (final type in _custom)
      if (!type.removed) type,
  ];

  static EventType _fromRow(Map<String, Object?> row) => EventType(
    id: row['id']! as String,
    name: row['name']! as String,
    builtIn: false,
    removed: row['removed'] == 1,
  );
}
