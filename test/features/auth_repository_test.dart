import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pet_health_tracker/features/auth/auth_repository.dart';

class MockFirebaseAuth extends Mock implements FirebaseAuth {}

class MockGoogleSignIn extends Mock implements GoogleSignIn {}

class MockGoogleSignInAccount extends Mock implements GoogleSignInAccount {}

class MockUserCredential extends Mock implements UserCredential {}

class MockUser extends Mock implements User {}

class MockUserInfo extends Mock implements UserInfo {}

class MockAdditionalUserInfo extends Mock implements AdditionalUserInfo {}

void main() {
  late MockFirebaseAuth auth;
  late MockGoogleSignIn google;
  late AuthRepository repository;

  setUpAll(() {
    registerFallbackValue(GoogleAuthProvider.credential(idToken: 'fallback'));
    registerFallbackValue(AppleAuthProvider());
  });

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
    when(() => auth.signInWithProvider(any())).thenAnswer((_) async => MockUserCredential());
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

  test('signs in to Firebase with Apple, asking for the name and email', () async {
    await repository.signInWithApple();

    final provider =
        verify(() => auth.signInWithProvider(captureAny())).captured.single as AppleAuthProvider;
    expect(provider.scopes, containsAll(<String>['name', 'email']));
    verifyNever(google.authenticate);
  });

  test('signs out of both Firebase and Google', () async {
    await repository.signOut();

    verify(auth.signOut).called(1);
    verify(google.signOut).called(1);
  });

  group('deleting the account', () {
    late MockUser user;

    void signedInWith(String providerId) {
      final info = MockUserInfo();
      when(() => info.providerId).thenReturn(providerId);
      when(() => user.providerData).thenReturn([info]);
    }

    setUp(() {
      user = MockUser();
      when(() => auth.currentUser).thenReturn(user);
      when(user.delete).thenAnswer((_) async {});
      when(google.disconnect).thenAnswer((_) async {});
      when(() => auth.revokeTokenWithAuthorizationCode(any())).thenAnswer((_) async {});
      when(() => user.reauthenticateWithCredential(any()))
          .thenAnswer((_) async => MockUserCredential());
    });

    test('a Google user signs in to Google again', () async {
      signedInWith('google.com');

      expect(await repository.reauthenticate(), isNull);

      final credential =
          verify(() => user.reauthenticateWithCredential(captureAny())).captured.single
              as OAuthCredential;
      expect(credential.providerId, 'google.com');
      expect(credential.idToken, 'google-id-token');
    });

    test("an Apple user signs in to Apple again, giving Apple's authorization code", () async {
      signedInWith('apple.com');
      final info = MockAdditionalUserInfo();
      when(() => info.authorizationCode).thenReturn('apple-code');
      final credential = MockUserCredential();
      when(() => credential.additionalUserInfo).thenReturn(info);
      when(() => user.reauthenticateWithProvider(any())).thenAnswer((_) async => credential);

      expect(await repository.reauthenticate(), 'apple-code');
      verifyNever(google.authenticate);
    });

    test('other sign-in methods are not asked again', () async {
      signedInWith('password');

      expect(await repository.reauthenticate(), isNull);
      verifyNever(() => user.reauthenticateWithCredential(any()));
      verifyNever(() => user.reauthenticateWithProvider(any()));
    });

    test("revokes Apple's access before deleting the user", () async {
      signedInWith('apple.com');

      await repository.deleteUser(appleAuthorizationCode: 'apple-code');

      verifyInOrder([() => auth.revokeTokenWithAuthorizationCode('apple-code'), user.delete]);
      verifyNever(google.disconnect);
    });

    test('deletes the user, then disconnects Google', () async {
      signedInWith('google.com');

      await repository.deleteUser();

      verifyInOrder([user.delete, google.disconnect]);
      verifyNever(() => auth.revokeTokenWithAuthorizationCode(any()));
    });

    test('the user is deleted even if Google fails to disconnect', () async {
      signedInWith('google.com');
      when(google.disconnect)
          .thenThrow(const GoogleSignInException(code: GoogleSignInExceptionCode.unknownError));

      await repository.deleteUser();

      verify(user.delete).called(1);
    });

    test('a failed delete stops before disconnecting', () async {
      signedInWith('google.com');
      when(user.delete).thenThrow(FirebaseAuthException(code: 'requires-recent-login'));

      await expectLater(repository.deleteUser(), throwsA(isA<FirebaseAuthException>()));
      verifyNever(google.disconnect);
    });
  });
}
