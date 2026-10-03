import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pet_health_tracker/core/firebase_providers.dart';
import 'package:pet_health_tracker/features/auth/sign_in_screen.dart';

import '../helpers.dart';

void main() {
  late MockAuthRepository auth;

  setUp(() => auth = MockAuthRepository());

  Future<void> pumpScreen(WidgetTester tester) => tester.pumpScoped(
    const SignInScreen(),
    overrides: [authRepositoryProvider.overrideWithValue(auth)],
  );

  testWidgets('signs in with Google on tap', (tester) async {
    final completer = Completer<Never>();
    when(() => auth.signInWithGoogle()).thenAnswer((_) => completer.future);

    await pumpScreen(tester);
    await tester.tap(find.text('Sign in with Google'));
    await tester.pump();

    verify(() => auth.signInWithGoogle()).called(1);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('shows no error when the user cancels', (tester) async {
    when(() => auth.signInWithGoogle())
        .thenThrow(const GoogleSignInException(code: GoogleSignInExceptionCode.canceled));

    await pumpScreen(tester);
    await tester.tap(find.text('Sign in with Google'));
    await tester.pumpAndSettle();

    expect(find.textContaining('GoogleSignInException'), findsNothing);
    expect(find.text('Sign in with Google'), findsOneWidget);
  });

  testWidgets('shows the error when Google sign-in fails', (tester) async {
    when(() => auth.signInWithGoogle()).thenThrow(
      const GoogleSignInException(code: GoogleSignInExceptionCode.clientConfigurationError),
    );

    await pumpScreen(tester);
    await tester.tap(find.text('Sign in with Google'));
    await tester.pumpAndSettle();

    expect(find.textContaining('clientConfigurationError'), findsOneWidget);
    expect(find.text('Sign in with Google'), findsOneWidget);
  });

  testWidgets('shows the error when Firebase sign-in fails', (tester) async {
    when(() => auth.signInWithGoogle()).thenThrow(Exception('network down'));

    await pumpScreen(tester);
    await tester.tap(find.text('Sign in with Google'));
    await tester.pumpAndSettle();

    expect(find.textContaining('network down'), findsOneWidget);
  });
}
