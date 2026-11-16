import 'package:sqflite/sqflite.dart';

import '../../domain/names.dart';
import '../../domain/pet.dart';
import '../repositories.dart';
import 'change_signal.dart';

/// [PetRepository] on the app's SQLite database.
class LocalPetRepository implements PetRepository {
  LocalPetRepository(this._db, this._clock, this._ids);

  final Database _db;
  final Clock _clock;
  final IdGenerator _ids;

  final _changes = ChangeSignal();

  @override
  Stream<List<Pet>> watchActive() => _changes.watch(() => _byName(archived: false));

  @override
  Stream<List<Pet>> watchArchived() => _changes.watch(() => _byName(archived: true));

  @override
  Stream<Pet?> watch(String id) => _changes.watch(() async {
    final rows = await _db.query('pets', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : _fromRow(rows.single);
  });

  @override
  Future<Pet> add({required String name, required Species species}) async {
    final pet = Pet(
      id: _ids(),
      name: validPetName(name),
      species: species,
      createdAt: _clock().toUtc(),
    );
    await _db.insert('pets', {
      'id': pet.id,
      'name': pet.name,
      'species': pet.species.id,
      'archived': 0,
      'created_at': pet.createdAt.millisecondsSinceEpoch,
    });
    _changes.notify();
    return pet;
  }

  @override
  Future<void> update(String id, {required String name, required Species species}) {
    return _write(id, {'name': validPetName(name), 'species': species.id});
  }

  @override
  Future<void> setArchived(String id, bool archived) {
    return _write(id, {'archived': archived ? 1 : 0});
  }

  Future<void> _write(String id, Map<String, Object> values) async {
    await _db.update('pets', values, where: 'id = ?', whereArgs: [id]);
    _changes.notify();
  }

  /// Pets with the given [archived] flag, by name ignoring case, then by id
  /// so pets with the same name keep their places.
  Future<List<Pet>> _byName({required bool archived}) async {
    final rows = await _db.query('pets', where: 'archived = ?', whereArgs: [archived ? 1 : 0]);
    return rows.map(_fromRow).toList()..sort(_compareByName);
  }

  static final _compareByName = byName<Pet>(name: (pet) => pet.name, id: (pet) => pet.id);

  static Pet _fromRow(Map<String, Object?> row) => Pet(
    id: row['id']! as String,
    name: row['name']! as String,
    species: Species.fromId(row['species']! as String),
    archived: row['archived'] == 1,
    createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at']! as int, isUtc: true),
  );
}
