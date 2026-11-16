import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../support/test_database.dart';

/// Each column as `name type notnull default pk`, from `PRAGMA table_info`.
Future<List<String>> columnsOf(Database db, String table) async {
  final rows = await db.rawQuery('PRAGMA table_info($table)');
  return [
    for (final r in rows) '${r['name']} ${r['type']} ${r['notnull']} ${r['dflt_value']} ${r['pk']}',
  ];
}

Map<String, Object> event({required String id, required String petId}) => {
  'id': id,
  'pet_id': petId,
  'type_id': 'vomiting',
  'occurred_at': 1000,
  'created_at': 1000,
  'updated_at': 1000,
};

void main() {
  late Database db;

  setUp(() async {
    db = await openTestDatabase();
  });

  tearDown(() => db.close());

  test('opens at schema version 1', () async {
    expect(await db.getVersion(), 1);
  });

  test('has the four tables and no others', () async {
    final rows = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%' "
      "AND name != 'android_metadata' ORDER BY name",
    );

    expect(rows.map((r) => r['name']), ['event_types', 'events', 'pets', 'settings']);
  });

  test('pets has the data model columns', () async {
    expect(await columnsOf(db, 'pets'), [
      'id TEXT 0 null 1',
      'name TEXT 1 null 0',
      'species TEXT 1 null 0',
      'archived INTEGER 1 0 0',
      'created_at INTEGER 1 null 0',
    ]);
  });

  test('event_types has the data model columns', () async {
    expect(await columnsOf(db, 'event_types'), [
      'id TEXT 0 null 1',
      'name TEXT 1 null 0',
      'match_key TEXT 1 null 0',
      'removed INTEGER 1 0 0',
    ]);
  });

  test('events has the data model columns', () async {
    expect(await columnsOf(db, 'events'), [
      'id TEXT 0 null 1',
      'pet_id TEXT 1 null 0',
      'type_id TEXT 1 null 0',
      'occurred_at INTEGER 1 null 0',
      "details TEXT 1 '{}' 0",
      'note TEXT 0 null 0',
      'created_at INTEGER 1 null 0',
      'updated_at INTEGER 1 null 0',
    ]);
  });

  test('settings has the data model columns', () async {
    expect(await columnsOf(db, 'settings'), ['key TEXT 0 null 1', 'value TEXT 1 null 0']);
  });

  test('events_pet_time indexes events by pet, newest first', () async {
    final index = await db.rawQuery(
      "SELECT tbl_name FROM sqlite_master WHERE type = 'index' AND name = 'events_pet_time'",
    );
    expect(index.single['tbl_name'], 'events');

    final keys = await db.rawQuery('PRAGMA index_xinfo(events_pet_time)');
    expect(
      [for (final k in keys.where((k) => k['key'] == 1)) '${k['name']} ${k['desc']}'],
      ['pet_id 0', 'occurred_at 1'],
    );
  });

  test('an event for an unknown pet is refused', () async {
    await db.insert('pets', {'id': 'p1', 'name': 'Rex', 'species': 'dog', 'created_at': 1000});
    await db.insert('events', event(id: 'e1', petId: 'p1'));

    await expectLater(
      db.insert('events', event(id: 'e2', petId: 'unknown')),
      throwsA(isA<DatabaseException>()),
    );
    expect(await db.query('events', columns: ['id']), [
      {'id': 'e1'},
    ]);
  });

  test('two custom types cannot share a match key', () async {
    await db.insert('event_types', {'id': 't1', 'name': 'Ear shaking', 'match_key': 'ear shaking'});

    await expectLater(
      db.insert('event_types', {'id': 't2', 'name': 'EAR SHAKING', 'match_key': 'ear shaking'}),
      throwsA(isA<DatabaseException>()),
    );
  });
}
