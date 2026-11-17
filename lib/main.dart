import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import 'app.dart';
import 'data/local/database.dart';
import 'data/local/local_event_repository.dart';
import 'data/local/local_event_type_repository.dart';
import 'data/local/local_pet_repository.dart';
import 'firebase_options.dart';

/// The name of the app's database file in the platform's databases folder.
const databaseFileName = 'pet_health_tracker.db';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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

  final db = await openAppDatabase(
    databaseFactory,
    join(await getDatabasesPath(), databaseFileName),
  );
  final ids = const Uuid().v4;
  final eventTypes = await LocalEventTypeRepository.open(db, ids);
  runApp(
    App(
      pets: LocalPetRepository(db, DateTime.now, ids),
      eventTypes: eventTypes,
      events: LocalEventRepository(db, eventTypes, DateTime.now, ids),
      clock: DateTime.now,
    ),
  );
}
