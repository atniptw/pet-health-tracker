import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_health_tracker/data/local/local_event_repository.dart';
import 'package:pet_health_tracker/data/local/local_event_type_repository.dart';
import 'package:pet_health_tracker/data/local/local_pet_repository.dart';
import 'package:pet_health_tracker/data/repositories.dart';
import 'package:pet_health_tracker/ui/app_scope.dart';

import 'test_database.dart';

/// The local repositories on an in-memory database, for screen tests.
class TestApp {
  TestApp._(this.pets, this.eventTypes, this.events, this.clock);

  final PetRepository pets;
  final EventTypeRepository eventTypes;
  final EventRepository events;

  /// The clock the repositories read, for screens that take one.
  final Clock clock;

  /// [child] in a [MaterialApp] inside an [AppScope] with these repositories.
  Widget wrap(Widget child) => AppScope(
    pets: pets,
    eventTypes: eventTypes,
    events: events,
    child: MaterialApp(home: child),
  );
}

/// Opens a [TestApp] whose clock always reads [now] (default 2026-11-14 12:00
/// local) and whose ids are `id-1`, `id-2`, …; the database closes when the
/// test ends.
Future<TestApp> openTestApp({DateTime? now}) async {
  final db = await openTestDatabase();
  addTearDown(db.close);
  final time = now ?? DateTime(2026, 11, 14, 12);
  DateTime clock() => time;
  var count = 0;
  String ids() => 'id-${++count}';
  final eventTypes = await LocalEventTypeRepository.open(db, ids);
  return TestApp._(
    LocalPetRepository(db, clock, ids),
    eventTypes,
    LocalEventRepository(db, eventTypes, clock, ids),
    clock,
  );
}
