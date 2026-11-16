import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pet_health_tracker/data/local/database.dart';
import 'package:pet_health_tracker/data/local/local_event_repository.dart';
import 'package:pet_health_tracker/data/local/local_event_type_repository.dart';
import 'package:pet_health_tracker/data/local/local_pet_repository.dart';
import 'package:pet_health_tracker/data/repositories.dart';
import 'package:pet_health_tracker/domain/event_type.dart';
import 'package:pet_health_tracker/domain/medical_event.dart';
import 'package:pet_health_tracker/domain/pet.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../support/test_database.dart';

/// The next value [stream] emits.
Future<T> next<T>(StreamIterator<T> stream) async {
  expect(await stream.moveNext(), isTrue);
  return stream.current;
}

final loggedAt = DateTime.utc(2026, 11, 14, 18);

void main() {
  late Database db;
  late DateTime now;
  late LocalEventTypeRepository types;
  late LocalEventRepository repo;
  late Pet max;
  late Pet bella;

  Future<LocalEventRepository> openRepository(Database db) async {
    var id = 0;
    types = await LocalEventTypeRepository.open(db, () => 'type-${++id}');
    var eventId = 0;
    return LocalEventRepository(db, types, () => now, () => 'event-${++eventId}');
  }

  setUp(() async {
    now = loggedAt;
    db = await openTestDatabase();
    var petId = 0;
    final pets = LocalPetRepository(db, () => now, () => 'pet-${++petId}');
    max = await pets.add(name: 'Max', species: Species.dog);
    bella = await pets.add(name: 'Bella', species: Species.cat);
    repo = await openRepository(db);
  });

  tearDown(() => db.close());

  Future<MedicalEvent> logSeizure({DateTime? at, String? petId}) => repo.log(
    petId: petId ?? max.id,
    type: ExistingType('seizure'),
    occurredAt: at ?? now.subtract(const Duration(hours: 1)),
  );

  Future<void> archive(Pet pet) =>
      db.update('pets', {'archived': 1}, where: 'id = ?', whereArgs: [pet.id]);

  Future<List<Map<String, Object?>>> settings() => db.query('settings');

  group('log', () {
    test('001-FR-003: writes the event with created and updated set to now', () async {
      final at = DateTime.utc(2026, 11, 14, 9, 30);
      final event = await repo.log(
        petId: max.id,
        type: ExistingType('seizure'),
        occurredAt: at,
        details: {'kind': 'grand_mal', 'duration': 150},
        note: '  After breakfast  ',
      );

      final expected = MedicalEvent(
        id: 'event-1',
        petId: max.id,
        typeId: 'seizure',
        occurredAt: at,
        details: const {'kind': 'grand_mal', 'duration': 150},
        note: 'After breakfast',
        createdAt: loggedAt,
        updatedAt: loggedAt,
      );
      expect(event, expected);
      expect(await repo.watch('event-1').first, expected);
    });

    test('001-FR-003: an event at exactly now is accepted', () async {
      final event = await logSeizure(at: now);

      expect(event.occurredAt, now);
      expect(await repo.watchForPet(max.id).first, [event]);
    });

    test('001-EC-01: an event after now is refused and nothing is written', () async {
      await expectLater(
        logSeizure(at: now.add(const Duration(milliseconds: 1))),
        throwsArgumentError,
      );
      expect(await db.query('events'), isEmpty);
      expect(await settings(), isEmpty);
    });

    test('001-FR-003: an event at an earlier date and time is accepted', () async {
      final at = DateTime.utc(2025, 3, 2, 4, 5);
      expect((await logSeizure(at: at)).occurredAt, at);
    });

    test('an archived pet is refused', () async {
      await archive(max);

      await expectLater(logSeizure(), throwsArgumentError);
      expect(await db.query('events'), isEmpty);
    });

    test('a detail key that is not one of the type\'s questions is refused', () async {
      await expectLater(
        repo.log(
          petId: max.id,
          type: ExistingType('seizure'),
          occurredAt: now,
          details: {'leg': 'front_left'},
        ),
        throwsArgumentError,
      );
      expect(await db.query('events'), isEmpty);
    });

    test('a value that does not fit its question is refused', () async {
      await expectLater(
        repo.log(
          petId: max.id,
          type: ExistingType('seizure'),
          occurredAt: now,
          details: {'duration': 0},
        ),
        throwsArgumentError,
      );
      expect(await db.query('events'), isEmpty);
    });

    test('details for a typed name are checked against the type it matches', () async {
      final event = await repo.log(
        petId: max.id,
        type: NewTypeName('SEIZURE'),
        occurredAt: now,
        details: {'kind': 'focal'},
      );
      expect(event.typeId, 'seizure');
      expect(event.details, {'kind': 'focal'});
    });

    test('a new custom type has no questions, so any detail is refused', () async {
      await expectLater(
        repo.log(
          petId: max.id,
          type: NewTypeName('Ear shaking'),
          occurredAt: now,
          details: {'duration': 5},
        ),
        throwsArgumentError,
      );
      expect(await db.query('event_types'), isEmpty);
    });

    test('the note goes through validNote: empty becomes null, over 1000 is refused', () async {
      final blank = await repo.log(
        petId: max.id,
        type: ExistingType('sneezing'),
        occurredAt: now,
        note: '   ',
      );
      expect(blank.note, isNull);
      expect((await db.query('events')).single['note'], isNull);

      await expectLater(
        repo.log(petId: max.id, type: ExistingType('sneezing'), occurredAt: now, note: 'a' * 1001),
        throwsArgumentError,
      );
      expect(await db.query('events'), hasLength(1));
    });

    test('details are stored as a JSON object', () async {
      await repo.log(
        petId: max.id,
        type: ExistingType('seizure'),
        occurredAt: now,
        details: {'kind': 'focal', 'duration': 90},
      );

      final stored = (await db.query('events')).single['details']! as String;
      expect(jsonDecode(stored), {'kind': 'focal', 'duration': 90});
    });

    test('sets the last logged pet', () async {
      expect(await repo.lastLoggedPetId(), isNull);

      await logSeizure(petId: bella.id);
      expect(await repo.lastLoggedPetId(), bella.id);

      await logSeizure(petId: max.id);
      expect(await repo.lastLoggedPetId(), max.id);
    });

    test('a new name is saved as a custom type and the type streams emit it', () async {
      final custom = StreamIterator(types.watchCustom());
      expect(await next(custom), isEmpty);

      final event = await repo.log(
        petId: max.id,
        type: NewTypeName('Ear shaking'),
        occurredAt: now,
      );

      expect(event.typeId, 'type-1');
      expect(await next(custom), [
        const EventType(id: 'type-1', name: 'Ear shaking', builtIn: false),
      ]);
      await custom.cancel();
    });

    test('a removed custom type typed again is un-removed', () async {
      await repo.log(petId: max.id, type: NewTypeName('Ear shaking'), occurredAt: now);
      await types.remove('type-1');

      await repo.log(petId: max.id, type: NewTypeName('ear shaking'), occurredAt: now);

      expect(await types.watchCustom().first, [
        const EventType(id: 'type-1', name: 'Ear shaking', builtIn: false),
      ]);
    });

    test(
      '001-SC-004: a failed write leaves no event, no new type and no last logged pet',
      () async {
        await logSeizure(petId: bella.id);

        await expectLater(
          repo.log(petId: 'no-such-pet', type: NewTypeName('Ear shaking'), occurredAt: now),
          throwsA(isA<DatabaseException>()),
        );

        expect(await db.query('events'), hasLength(1));
        expect(await db.query('event_types'), isEmpty);
        expect(await repo.lastLoggedPetId(), bella.id);
      },
    );

    test('001-EC-02: two events of the same type seconds apart are both kept', () async {
      final first = await logSeizure(at: now.subtract(const Duration(seconds: 5)));
      final second = await logSeizure(at: now.subtract(const Duration(seconds: 2)));

      expect(await repo.watchForPet(max.id).first, [second, first]);
    });

    test('001-EC-03: an event is saved and the pet\'s list shows it at once', () async {
      final events = StreamIterator(repo.watchForPet(max.id));
      expect(await next(events), isEmpty);

      final event = await logSeizure();

      expect(await next(events), [event]);
      await events.cancel();
    });
  });

  group('update', () {
    late MedicalEvent original;

    setUp(() async {
      original = await repo.log(
        petId: max.id,
        type: ExistingType('seizure'),
        occurredAt: DateTime.utc(2026, 11, 14, 9),
        details: {'kind': 'focal'},
        note: 'Short',
      );
      now = loggedAt.add(const Duration(hours: 2));
    });

    Future<void> update({
      String? petId,
      TypeChoice? type,
      DateTime? occurredAt,
      Map<String, Object> details = const {},
      String? note,
    }) => repo.update(
      original.id,
      petId: petId ?? max.id,
      type: type ?? ExistingType('seizure'),
      occurredAt: occurredAt ?? original.occurredAt,
      details: details,
      note: note,
    );

    test('writes every field and a new updatedAt, keeping createdAt', () async {
      final at = DateTime.utc(2026, 11, 13, 22);
      await update(
        petId: bella.id,
        type: ExistingType('coughing'),
        occurredAt: at,
        details: {'duration': 30},
        note: 'Changed',
      );

      expect(
        await repo.watch(original.id).first,
        MedicalEvent(
          id: original.id,
          petId: bella.id,
          typeId: 'coughing',
          occurredAt: at,
          details: const {'duration': 30},
          note: 'Changed',
          createdAt: loggedAt,
          updatedAt: now,
        ),
      );
    });

    test('leaves the last logged pet alone', () async {
      await update(petId: bella.id);

      expect(await repo.lastLoggedPetId(), max.id);
    });

    test('001-EC-01: a time after now is refused', () async {
      await expectLater(
        update(occurredAt: now.add(const Duration(seconds: 1))),
        throwsArgumentError,
      );
      expect(await repo.watch(original.id).first, original);
    });

    test('a time of exactly now is accepted', () async {
      await update(occurredAt: now);
      expect((await repo.watch(original.id).first)!.occurredAt, now);
    });

    test('moving the event to an archived pet is refused', () async {
      await archive(bella);

      await expectLater(update(petId: bella.id), throwsArgumentError);
      expect(await repo.watch(original.id).first, original);
    });

    test('an archived pet that is the event\'s current pet is allowed', () async {
      await archive(max);

      await update(note: 'Edited after archiving');

      expect((await repo.watch(original.id).first)!.note, 'Edited after archiving');
    });

    test('a detail key that is not one of the type\'s questions is refused', () async {
      await expectLater(update(details: {'leg': 'front_left'}), throwsArgumentError);
      expect(await repo.watch(original.id).first, original);
    });

    test('a value that does not fit its question is refused', () async {
      await expectLater(update(details: {'kind': 'tonic'}), throwsArgumentError);
      expect(await repo.watch(original.id).first, original);
    });

    test('the note goes through validNote', () async {
      await update(note: '  ');
      expect((await repo.watch(original.id).first)!.note, isNull);

      await expectLater(update(note: 'a' * 1001), throwsArgumentError);
    });

    test('a new name is saved as a custom type and the type streams emit it', () async {
      final custom = StreamIterator(types.watchCustom());
      expect(await next(custom), isEmpty);

      await update(type: NewTypeName('Ear shaking'));

      expect((await repo.watch(original.id).first)!.typeId, 'type-1');
      expect(await next(custom), [
        const EventType(id: 'type-1', name: 'Ear shaking', builtIn: false),
      ]);
      await custom.cancel();
    });

    test('001-SC-004: a failed write leaves the event as it was and no new type', () async {
      await expectLater(
        update(petId: 'no-such-pet', type: NewTypeName('Ear shaking')),
        throwsA(isA<DatabaseException>()),
      );

      expect(await repo.watch(original.id).first, original);
      expect(await db.query('event_types'), isEmpty);
    });
  });

  group('watchForPet', () {
    test('lists the pet\'s events newest first by when they happened', () async {
      final middle = await logSeizure(at: DateTime.utc(2026, 11, 10));
      final newest = await logSeizure(at: DateTime.utc(2026, 11, 12));
      final oldest = await logSeizure(at: DateTime.utc(2026, 11, 1));
      await logSeizure(petId: bella.id, at: DateTime.utc(2026, 11, 11));

      expect(await repo.watchForPet(max.id).first, [newest, middle, oldest]);
    });

    /// A repository whose events get [ids] in turn.
    LocalEventRepository withIds(List<String> ids) {
      final next = ids.iterator;
      return LocalEventRepository(db, types, () => now, () => (next..moveNext()).current);
    }

    test('events at the same moment are listed most recently logged first', () async {
      final events = withIds(['event-b', 'event-a']);
      final at = DateTime.utc(2026, 11, 10);
      final first = await events.log(petId: max.id, type: ExistingType('seizure'), occurredAt: at);
      now = now.add(const Duration(minutes: 1));
      final second = await events.log(petId: max.id, type: ExistingType('seizure'), occurredAt: at);

      expect(second.id, 'event-a');
      expect(await events.watchForPet(max.id).first, [second, first]);
    });

    test(
      'events at the same moment logged at the same time are listed by id, last first',
      () async {
        final events = withIds(['event-b', 'event-c', 'event-a']);
        final at = DateTime.utc(2026, 11, 10);
        final logged = [
          for (var i = 0; i < 3; i++)
            await events.log(petId: max.id, type: ExistingType('seizure'), occurredAt: at),
        ];

        expect(
          [for (final event in await events.watchForPet(max.id).first) event.id],
          ['event-c', 'event-b', 'event-a'],
        );
        expect(logged.map((event) => event.createdAt).toSet(), {now});
      },
    );
  });

  group('delete', () {
    test('removes the row and watch emits null', () async {
      final event = await logSeizure();
      final watched = StreamIterator(repo.watch(event.id));
      expect(await next(watched), event);

      await repo.delete(event.id);

      expect(await next(watched), isNull);
      expect(await db.query('events'), isEmpty);
      await watched.cancel();
    });
  });

  test(
    '001-EC-06: the moment is read back as the same UTC instant whatever zone it was given in',
    () async {
      final local = DateTime(2026, 11, 14, 8, 15, 30, 250);
      final event = await logSeizure(at: local);

      final read = (await repo.watch(event.id).first)!.occurredAt;
      expect(read.isUtc, isTrue);
      expect(read, local.toUtc());
      expect(read.millisecondsSinceEpoch, local.millisecondsSinceEpoch);
      expect((await db.query('events')).single['occurred_at'], local.millisecondsSinceEpoch);
    },
  );

  test(
    '001-FR-012: an event is still there after the database file is closed and opened again',
    () async {
      final dir = await Directory.systemTemp.createTemp('event_repository_test');
      addTearDown(() => dir.delete(recursive: true));
      final path = '${dir.path}/app.db';

      var fileDb = await openAppDatabase(databaseFactoryFfi, path);
      await fileDb.insert('pets', {
        'id': 'pet-1',
        'name': 'Max',
        'species': 'dog',
        'archived': 0,
        'created_at': 0,
      });
      final event = await (await openRepository(fileDb)).log(
        petId: 'pet-1',
        type: NewTypeName('Ear shaking'),
        occurredAt: now,
        details: const {},
        note: 'Kept',
      );
      await fileDb.close();

      fileDb = await openAppDatabase(databaseFactoryFfi, path);
      addTearDown(fileDb.close);
      final reopened = await openRepository(fileDb);

      expect(await reopened.watchForPet('pet-1').first, [event]);
      expect(await reopened.lastLoggedPetId(), 'pet-1');
      expect((await types.byId(event.typeId)).name, 'Ear shaking');
    },
  );
}
