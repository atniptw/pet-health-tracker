import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_health_tracker/core/app.dart';
import 'package:pet_health_tracker/core/firebase_providers.dart';

void main() {
  testWidgets('shows the sign-in screen when signed out', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateChangesProvider.overrideWith((ref) => Stream.value(null)),
        ],
        child: const App(),
      ),
    );
    await tester.pump();

    expect(find.text('Sign in with Google'), findsOneWidget);
  });

  testWidgets('shows a retry button when the auth stream errors', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        // Riverpod retries failing providers by default, which would hold the
        // gate in its loading state instead of surfacing the error.
        retry: (retryCount, error) => null,
        overrides: [
          authStateChangesProvider.overrideWith((ref) => Stream.error('auth failed')),
        ],
        child: const App(),
      ),
    );
    await tester.pump();

    expect(find.text('auth failed'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Retry'), findsOneWidget);
  });
}
