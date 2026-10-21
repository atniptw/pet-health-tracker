import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthRepository {
  AuthRepository(this._auth, [GoogleSignIn? googleSignIn])
    : _googleSignIn = googleSignIn ?? GoogleSignIn.instance;

  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;

  Future<void>? _initialized;

  Future<void> _ensureInitialized() {
    return _initialized ??= _googleSignIn.initialize();
  }

  Future<UserCredential> signInWithGoogle() async {
    await _ensureInitialized();
    final account = await _googleSignIn.authenticate();
    final idToken = account.authentication.idToken;
    final credential = GoogleAuthProvider.credential(idToken: idToken);
    return _auth.signInWithCredential(credential);
  }

  /// Uses Apple's native sign-in sheet on iOS. Apple shares the name only the
  /// first time, and Firebase saves it as the new user's display name.
  Future<UserCredential> signInWithApple() {
    final provider = AppleAuthProvider()
      ..addScope('email')
      ..addScope('name');
    return _auth.signInWithProvider(provider);
  }

  /// Signs in again with Google or Apple, as Firebase requires shortly
  /// before deleting an account. Returns Apple's authorization code, which
  /// [deleteUser] needs to revoke the app's access, or null.
  Future<String?> reauthenticate() async {
    final user = _auth.currentUser!;
    final providers = user.providerData.map((info) => info.providerId);
    if (providers.contains('apple.com')) {
      final credential = await user.reauthenticateWithProvider(AppleAuthProvider());
      return credential.additionalUserInfo?.authorizationCode;
    }
    if (providers.contains('google.com')) {
      await _ensureInitialized();
      final account = await _googleSignIn.authenticate();
      await user.reauthenticateWithCredential(
        GoogleAuthProvider.credential(idToken: account.authentication.idToken),
      );
    }
    return null;
  }

  /// Deletes the signed-in user's account, which signs them out. Revokes the
  /// app's access to their Apple ID first, given [appleAuthorizationCode] from
  /// [reauthenticate], or to their Google account after.
  Future<void> deleteUser({String? appleAuthorizationCode}) async {
    final user = _auth.currentUser!;
    final usedGoogle = user.providerData.any((info) => info.providerId == 'google.com');
    if (appleAuthorizationCode != null) {
      await _auth.revokeTokenWithAuthorizationCode(appleAuthorizationCode);
    }
    await user.delete();
    if (usedGoogle) {
      try {
        await _ensureInitialized();
        await _googleSignIn.disconnect();
      } on GoogleSignInException {
        // The account is already deleted; the Google grant is all that's left.
      }
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
    await _googleSignIn.signOut();
  }
}
