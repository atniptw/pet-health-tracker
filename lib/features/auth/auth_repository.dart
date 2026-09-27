import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthRepository {
  AuthRepository(this._auth);

  final FirebaseAuth _auth;

  Future<void>? _initialized;

  Future<void> _ensureInitialized() {
    return _initialized ??= GoogleSignIn.instance.initialize();
  }

  Future<UserCredential> signInWithGoogle() async {
    await _ensureInitialized();
    final account = await GoogleSignIn.instance.authenticate();
    final idToken = account.authentication.idToken;
    final credential = GoogleAuthProvider.credential(idToken: idToken);
    return _auth.signInWithCredential(credential);
  }

  Future<void> signOut() async {
    await _auth.signOut();
    await GoogleSignIn.instance.signOut();
  }
}
