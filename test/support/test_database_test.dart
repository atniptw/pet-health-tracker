import 'package:flutter_test/flutter_test.dart';

import 'test_database.dart';

void main() {
  test('opens an in-memory SQLite database on the test host', () async {
    final db = await openTestDatabase();
    addTearDown(db.close);

    final rows = await db.rawQuery('SELECT sqlite_version() AS version');

    expect(rows.single['version'], isA<String>());
  });

  test('each call opens a separate database', () async {
    final first = await openTestDatabase();
    addTearDown(first.close);
    final second = await openTestDatabase();
    addTearDown(second.close);

    await first.execute('CREATE TABLE t (x)');
    await first.insert('t', {'x': 1});

    final tables = await second.rawQuery("SELECT name FROM sqlite_master WHERE name = 't'");
    expect(tables, isEmpty);
  });
}
