import 'package:sqflite/sqflite.dart';

const _schemaV1 = [
  '''
CREATE TABLE pets (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  species TEXT NOT NULL,
  archived INTEGER NOT NULL DEFAULT 0,
  created_at INTEGER NOT NULL
)''',
  '''
CREATE TABLE event_types (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  match_key TEXT NOT NULL UNIQUE,
  removed INTEGER NOT NULL DEFAULT 0
)''',
  '''
CREATE TABLE events (
  id TEXT PRIMARY KEY,
  pet_id TEXT NOT NULL REFERENCES pets(id),
  type_id TEXT NOT NULL,
  occurred_at INTEGER NOT NULL,
  details TEXT NOT NULL DEFAULT '{}',
  note TEXT,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
)''',
  'CREATE INDEX events_pet_time ON events (pet_id, occurred_at DESC)',
  '''
CREATE TABLE settings (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL
)''',
];

/// Opens the app's database at [path] through [factory], creating schema
/// version 1 (data-model.md) on first open, with foreign keys enforced.
///
/// Each call opens its own connection, so separate in-memory databases stay
/// apart.
Future<Database> openAppDatabase(DatabaseFactory factory, String path) {
  return factory.openDatabase(
    path,
    options: OpenDatabaseOptions(
      version: 1,
      singleInstance: false,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, version) async {
        for (final statement in _schemaV1) {
          await db.execute(statement);
        }
      },
    ),
  );
}
