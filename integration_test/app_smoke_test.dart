import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart';
import 'package:pet_health_tracker/domain/pet.dart';
import 'package:pet_health_tracker/main.dart' as app;
import 'package:sqflite/sqflite.dart';

import '../test/support/robot.dart';

/// Pumps frames until [finder] finds a widget or [timeout] passes. On a
/// device a save's SQLite write runs outside the test's frames, so
/// `pumpAndSettle` can return before the write is done and the screen moves
/// on.
Future<void> pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final end = DateTime.now().add(timeout);
  while (finder.evaluate().isEmpty && DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Boots the real app on a device, with its SQLite database and no network
/// or sign-in, to catch what widget tests can't see.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('001-FR-014: signed out, adds Rex and logs Vomiting for him on a device', (
    tester,
  ) async {
    // The database outlives the app on the device; start from none.
    await deleteDatabase(join(await getDatabasesPath(), app.databaseFileName));
    await app.main();
    await tester.pumpAndSettle();
    final robot = Robot(tester);

    await robot.addPet('Rex', Species.dog);
    await pumpUntilFound(tester, find.widgetWithText(FilledButton, 'Vomiting'));
    await robot.logEvent('Vomiting');
    await pumpUntilFound(tester, find.text('Saved: Vomiting for Rex'));

    expect(find.text('Saved: Vomiting for Rex'), findsOneWidget);
  });
}
