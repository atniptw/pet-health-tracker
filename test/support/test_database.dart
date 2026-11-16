import 'package:pet_health_tracker/data/local/database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Opens a fresh in-memory app database through FFI, so tests run real SQL
/// on the test host without a device. It runs in the test's own isolate, so
/// a write a widget starts finishes within `tester.pump`.
Future<Database> openTestDatabase() {
  sqfliteFfiInit();
  return openAppDatabase(databaseFactoryFfiNoIsolate, inMemoryDatabasePath);
}
