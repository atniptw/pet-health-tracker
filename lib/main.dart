import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/app.dart';
import 'core/theme.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  registerFontLicenses();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Crash reports come from release builds only. Debug builds keep Flutter's
  // default error handlers, which print to the console.
  final crashlytics = FirebaseCrashlytics.instance;
  await crashlytics.setCrashlyticsCollectionEnabled(kReleaseMode);
  if (kReleaseMode) {
    FlutterError.onError = crashlytics.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (error, stack) {
      unawaited(crashlytics.recordError(error, stack, fatal: true));
      return true;
    };
  }

  if (kDebugMode) {
    final emulatorHost = defaultTargetPlatform == TargetPlatform.android ? '10.0.2.2' : 'localhost';
    await FirebaseAuth.instance.useAuthEmulator(emulatorHost, 9099);
    FirebaseFirestore.instance.useFirestoreEmulator(emulatorHost, 8080);
  }

  runApp(const ProviderScope(child: App()));
}
