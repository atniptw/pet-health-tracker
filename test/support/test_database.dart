import 'package:pet_health_tracker/data/local/database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Opens a fresh in-memory app database through FFI, so tests run real SQL
/// on the test host without a device.
Future<Database> openTestDatabase() {
  sqfliteFfiInit();
  return openAppDatabase(databaseFactoryFfi, inMemoryDatabasePath);
}
