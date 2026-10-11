import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../core/firebase_providers.dart';

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  bool _signingIn = false;
  String? _error;

  Future<void> _signIn(Future<void> Function() signIn) async {
    setState(() {
      _signingIn = true;
      _error = null;
    });
    try {
      await signIn();
    } on GoogleSignInException catch (e) {
      if (e.code != GoogleSignInExceptionCode.canceled && mounted) {
        setState(() => _error = e.toString());
      }
    } on FirebaseAuthException catch (e) {
      // Closing Apple's sign-in sheet.
      if (e.code != 'canceled' && mounted) setState(() => _error = e.toString());
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _signingIn = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Apple requires Sign in with Apple on iOS when other social logins are offered.
    final offerApple = defaultTargetPlatform == TargetPlatform.iOS;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Pet Health Tracker'),
              const SizedBox(height: 24),
              if (_signingIn)
                const CircularProgressIndicator()
              else ...[
                if (offerApple) ...[
                  FilledButton.icon(
                    onPressed: () => _signIn(ref.read(authRepositoryProvider).signInWithApple),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.apple),
                    label: const Text('Sign in with Apple'),
                  ),
                  const SizedBox(height: 12),
                ],
                FilledButton(
                  onPressed: () => _signIn(ref.read(authRepositoryProvider).signInWithGoogle),
                  child: const Text('Sign in with Google'),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
