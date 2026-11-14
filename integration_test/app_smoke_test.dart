import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pet_health_tracker/app.dart';
import 'package:pet_health_tracker/main.dart' as app;

/// Boots the real app on a device to catch crashes on startup that widget
/// tests can't see.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('starts and says the app is being rebuilt', (tester) async {
    await app.main();
    await tester.pumpAndSettle();

    expect(find.text(App.message), findsOneWidget);
  });
}
