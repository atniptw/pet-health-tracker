import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pet_health_tracker/main.dart' as app;

/// Boots the real app on a device, against the Firebase emulators, to catch
/// crashes on startup that widget tests can't see.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('starts at the sign-in screen', (tester) async {
    await app.main();

    final signIn = find.text('Sign in with Google');
    final deadline = DateTime.now().add(const Duration(seconds: 30));
    while (signIn.evaluate().isEmpty && DateTime.now().isBefore(deadline)) {
      await tester.pump(const Duration(milliseconds: 200));
    }

    expect(signIn, findsOneWidget);
  });
}
