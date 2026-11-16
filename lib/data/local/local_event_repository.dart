import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../domain/medical_event.dart';
import '../repositories.dart';
import 'change_signal.dart';
import 'local_event_type_repository.dart';

const _lastLoggedPet = 'last_logged_pet_id';

/// [EventRepository] on the app's SQLite database.
class LocalEventRepository implements EventRepository {
  LocalEventRepository(this._db, this._types, this._clock, this._ids);

  final Database _db;
  final LocalEventTypeRepository _types;
  final Clock _clock;
  final IdGenerator _ids;

  final _changes = ChangeSignal();

  /// Newest first by when they happened; events at the same moment most
  /// recently logged first, then by id, so they keep their places (D-004).
  @override
  Stream<List<MedicalEvent>> watchForPet(String petId) => _changes.watch(() async {
    final rows = await _db.query(
      'events',
      where: 'pet_id = ?',
      whereArgs: [petId],
      orderBy: 'occurred_at DESC, created_at DESC, id DESC',
    );
    return rows.map(_fromRow).toList();
  });

  @override
  Stream<MedicalEvent?> watch(String id) => _changes.watch(() async {
    final rows = await _db.query('events', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : _fromRow(rows.single);
  });

  @override
  Future<MedicalEvent> log({
    required String petId,
    required TypeChoice type,
    required DateTime occurredAt,
    Map<String, Object> details = const {},
    String? note,
  }) async {
    final now = _clock().toUtc();
    final checked = await _checked(type, occurredAt, details, note, now);
    final id = _ids();
    final typeId = await _db.transaction((txn) async {
      await _checkPetActive(txn, petId);
      final typeId = await _types.resolveForSave(txn, type);
      await txn.insert('settings', {
        'key': _lastLoggedPet,
        'value': petId,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      await txn.insert('events', {
        'id': id,
        ..._fields(petId, typeId, checked, now),
        'created_at': now.millisecondsSinceEpoch,
      });
      return typeId;
    });
    await _notify(type);
    return MedicalEvent(
      id: id,
      petId: petId,
      typeId: typeId,
      occurredAt: checked.occurredAt,
      details: checked.details,
      note: checked.note,
      createdAt: now,
      updatedAt: now,
    );
  }

  @override
  Future<void> update(
    String id, {
    required String petId,
    required TypeChoice type,
    required DateTime occurredAt,
    required Map<String, Object> details,
    String? note,
  }) async {
    final now = _clock().toUtc();
    final checked = await _checked(type, occurredAt, details, note, now);
    await _db.transaction((txn) async {
      final current = await txn.query(
        'events',
        columns: ['pet_id'],
        where: 'id = ?',
        whereArgs: [id],
      );
      if (current.firstOrNull?['pet_id'] != petId) await _checkPetActive(txn, petId);
      final typeId = await _types.resolveForSave(txn, type);
      await txn.update(
        'events',
        _fields(petId, typeId, checked, now),
        where: 'id = ?',
        whereArgs: [id],
      );
    });
    await _notify(type);
  }

  @override
  Future<void> delete(String id) async {
    await _db.delete('events', where: 'id = ?', whereArgs: [id]);
    _changes.notify();
  }

  @override
  Future<String?> lastLoggedPetId() async {
    final rows = await _db.query('settings', where: 'key = ?', whereArgs: [_lastLoggedPet]);
    return rows.firstOrNull?['value'] as String?;
  }

  /// The values to write, after the checks [log] and [update] share.
  Future<_Checked> _checked(
    TypeChoice type,
    DateTime occurredAt,
    Map<String, Object> details,
    String? note,
    DateTime now,
  ) async {
    if (occurredAt.isAfter(now)) {
      throw ArgumentError('Must not be after now', 'occurredAt');
    }
    return (
      occurredAt: occurredAt.toUtc(),
      details: validDetailsFor(await _types.questionsFor(type), details),
      note: validNote(note),
    );
  }

  static Future<void> _checkPetActive(Transaction txn, String petId) async {
    final rows = await txn.query(
      'pets',
      columns: ['archived'],
      where: 'id = ?',
      whereArgs: [petId],
    );
    if (rows.firstOrNull?['archived'] == 1) {
      throw ArgumentError('The pet is archived', 'petId');
    }
  }

  /// Notifies this repository's streams, and the type repository's when
  /// [type] may have created or un-removed a custom type.
  Future<void> _notify(TypeChoice type) async {
    if (type is NewTypeName) await _types.notifyChanged();
    _changes.notify();
  }

  static Map<String, Object?> _fields(
    String petId,
    String typeId,
    _Checked checked,
    DateTime now,
  ) => {
    'pet_id': petId,
    'type_id': typeId,
    'occurred_at': checked.occurredAt.millisecondsSinceEpoch,
    'details': jsonEncode(checked.details),
    'note': checked.note,
    'updated_at': now.millisecondsSinceEpoch,
  };

  static MedicalEvent _fromRow(Map<String, Object?> row) => MedicalEvent(
    id: row['id']! as String,
    petId: row['pet_id']! as String,
    typeId: row['type_id']! as String,
    occurredAt: _utc(row['occurred_at']),
    details: (jsonDecode(row['details']! as String) as Map<String, dynamic>).cast<String, Object>(),
    note: row['note'] as String?,
    createdAt: _utc(row['created_at']),
    updatedAt: _utc(row['updated_at']),
  );

  static DateTime _utc(Object? millis) =>
      DateTime.fromMillisecondsSinceEpoch(millis! as int, isUtc: true);
}

typedef _Checked = ({DateTime occurredAt, Map<String, Object> details, String? note});
