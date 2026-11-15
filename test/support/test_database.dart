import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Opens a fresh in-memory SQLite database through FFI, so tests run real SQL
/// on the test host without a device.
Future<Database> openTestDatabase() {
  sqfliteFfiInit();
  return databaseFactoryFfi.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(singleInstance: false),
  );
}
