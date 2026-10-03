import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pet_health_tracker/features/auth/auth_repository.dart';

class MockFirebaseAuth extends Mock implements FirebaseAuth {}

class MockGoogleSignIn extends Mock implements GoogleSignIn {}

class MockGoogleSignInAccount extends Mock implements GoogleSignInAccount {}

class MockUserCredential extends Mock implements UserCredential {}

void main() {
  late MockFirebaseAuth auth;
  late MockGoogleSignIn google;
  late AuthRepository repository;

  setUpAll(() => registerFallbackValue(GoogleAuthProvider.credential(idToken: 'fallback')));

  setUp(() {
    auth = MockFirebaseAuth();
    google = MockGoogleSignIn();
    repository = AuthRepository(auth, google);

    final account = MockGoogleSignInAccount();
    when(() => account.authentication)
        .thenReturn(const GoogleSignInAuthentication(idToken: 'google-id-token'));
    when(google.initialize).thenAnswer((_) async {});
    when(google.authenticate).thenAnswer((_) async => account);
    when(google.signOut).thenAnswer((_) async {});
    when(auth.signOut).thenAnswer((_) async {});
    when(() => auth.signInWithCredential(any())).thenAnswer((_) async => MockUserCredential());
  });

  test("signs in to Firebase with the Google account's ID token", () async {
    await repository.signInWithGoogle();

    final credential =
        verify(() => auth.signInWithCredential(captureAny())).captured.single as OAuthCredential;
    expect(credential.providerId, 'google.com');
    expect(credential.idToken, 'google-id-token');
  });

  test('initializes Google sign-in only once', () async {
    await repository.signInWithGoogle();
    await repository.signInWithGoogle();

    verify(google.initialize).called(1);
    verify(google.authenticate).called(2);
  });

  test('does not sign in to Firebase when Google sign-in fails', () async {
    when(google.authenticate)
        .thenThrow(const GoogleSignInException(code: GoogleSignInExceptionCode.canceled));

    await expectLater(repository.signInWithGoogle(), throwsA(isA<GoogleSignInException>()));
    verifyNever(() => auth.signInWithCredential(any()));
  });

  test('signs out of both Firebase and Google', () async {
    await repository.signOut();

    verify(auth.signOut).called(1);
    verify(google.signOut).called(1);
  });
}
