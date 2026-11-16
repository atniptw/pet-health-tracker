import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pet_health_tracker/data/local/local_event_type_repository.dart';
import 'package:pet_health_tracker/data/repositories.dart';
import 'package:pet_health_tracker/domain/built_in_event_types.dart';
import 'package:pet_health_tracker/domain/event_type.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../support/test_database.dart';

List<String> names(List<EventType> types) => [for (final type in types) type.name];

final builtInNames = names(builtInEventTypes);

/// The next value [stream] emits.
Future<T> next<T>(StreamIterator<T> stream) async {
  expect(await stream.moveNext(), isTrue);
  return stream.current;
}

void main() {
  late Database db;
  late LocalEventTypeRepository repo;

  setUp(() async {
    db = await openTestDatabase();
    var id = 0;
    repo = await LocalEventTypeRepository.open(db, () => 'type-${++id}');
  });

  tearDown(() => db.close());

  /// Resolves [choice] in its own transaction, then notifies, as the event
  /// repository does when it saves an event.
  Future<String> save(TypeChoice choice) async {
    final id = await db.transaction((txn) => repo.resolveForSave(txn, choice));
    await repo.notifyChanged();
    return id;
  }

  Future<Map<String, Object?>> row(String id) async {
    return (await db.query('event_types', where: 'id = ?', whereArgs: [id])).single;
  }

  group('resolveForSave', () {
    test('an existing type returns its id', () async {
      expect(await save(ExistingType('seizure')), 'seizure');
      expect(await db.query('event_types'), isEmpty);
    });

    test('001-FR-004: a new name is saved as a custom type with a new id, keeping the caregiver\'s capitalization', () async {
      final id = await save(NewTypeName('  Ear   SHAKING '));

      expect(id, 'type-1');
      expect(await row(id), {
        'id': 'type-1',
        'name': 'Ear SHAKING',
        'match_key': 'ear shaking',
        'removed': 0,
      });
      expect(
        await repo.byId(id),
        const EventType(id: 'type-1', name: 'Ear SHAKING', builtIn: false),
      );
    });

    test('001-EC-07: "vomiting" is the built-in Vomiting and saves nothing', () async {
      expect(await save(NewTypeName('vomiting')), 'vomiting');
      expect(await db.query('event_types'), isEmpty);
    });

    test('001-EC-07: "  Ear   SHAKING " is the existing custom type Ear shaking', () async {
      await save(NewTypeName('Ear shaking'));

      expect(await save(NewTypeName('  Ear   SHAKING ')), 'type-1');
      expect(await db.query('event_types'), hasLength(1));
      expect((await row('type-1'))['name'], 'Ear shaking');
    });

    test('001-EC-04: typing a removed type again un-removes it with the same id, so its events count together', () async {
      await save(NewTypeName('Ear shaking'));
      await repo.remove('type-1');

      expect(await save(NewTypeName('ear shaking')), 'type-1');
      expect((await row('type-1'))['removed'], 0);
      expect(names(await repo.watchCustom().first), ['Ear shaking']);
      expect(names(await repo.watchOffered().first), [...builtInNames, 'Ear shaking']);
    });

    test('a name empty after collapsing or over 40 characters is refused', () async {
      await expectLater(save(NewTypeName('   ')), throwsArgumentError);
      await expectLater(save(NewTypeName('a' * 41)), throwsArgumentError);
      expect(await db.query('event_types'), isEmpty);
    });

    test('does not notify the streams itself', () async {
      final emitted = <List<EventType>>[];
      final sub = repo.watchCustom().listen(emitted.add);
      addTearDown(sub.cancel);
      await pumpEventQueue();
      expect(emitted, hasLength(1));

      await db.transaction((txn) => repo.resolveForSave(txn, NewTypeName('Ear shaking')));
      await pumpEventQueue();
      expect(emitted, hasLength(1));

      await repo.notifyChanged();
      await pumpEventQueue();
      expect(names(emitted.last), ['Ear shaking']);
    });
  });

  group('match', () {
    test('001-EC-07: "vomiting" matches the built-in Vomiting', () {
      expect(repo.match('vomiting'), builtInEventTypes.first);
    });

    test('001-EC-07: "  Ear   SHAKING " matches the custom type Ear shaking', () async {
      await save(NewTypeName('Ear shaking'));

      expect(
        repo.match('  Ear   SHAKING '),
        const EventType(id: 'type-1', name: 'Ear shaking', builtIn: false),
      );
    });

    test('001-EC-04: a removed custom type still matches', () async {
      await save(NewTypeName('Ear shaking'));
      await repo.remove('type-1');

      expect(repo.match('EAR SHAKING')?.id, 'type-1');
      expect(repo.match('EAR SHAKING')?.removed, isTrue);
    });

    test('a new name matches nothing', () {
      expect(repo.match('Ear shaking'), isNull);
    });

    test('answers from the types loaded at open and at the last notifyChanged', () async {
      await db.insert('event_types', {
        'id': 'custom-1',
        'name': 'Zoomies',
        'match_key': 'zoomies',
        'removed': 0,
      });
      expect(repo.match('zoomies'), isNull);

      final opened = await LocalEventTypeRepository.open(db, () => 'new-1');
      expect(opened.match('zoomies')?.id, 'custom-1');

      await db.transaction((txn) => opened.resolveForSave(txn, NewTypeName('Ear shaking')));
      expect(opened.match('ear shaking'), isNull);
      await opened.notifyChanged();
      expect(opened.match('ear shaking')?.id, 'new-1');
    });
  });

  group('byId', () {
    test('returns a built-in type', () async {
      expect(await repo.byId('seizure'), builtInEventTypes[2]);
    });

    test('001-FR-004: returns a removed custom type, so past events still have a name', () async {
      await save(NewTypeName('Ear shaking'));
      await repo.remove('type-1');

      expect(
        await repo.byId('type-1'),
        const EventType(id: 'type-1', name: 'Ear shaking', builtIn: false, removed: true),
      );
    });

    test('throws StateError for an unknown id', () async {
      await expectLater(repo.byId('nothing'), throwsStateError);
    });
  });

  group('questionsFor', () {
    test('an existing type gives its questions', () async {
      expect(await repo.questionsFor(ExistingType('seizure')), builtInEventTypes[2].questions);
    });

    test('a custom type gives none', () async {
      await save(NewTypeName('Ear shaking'));

      expect(await repo.questionsFor(ExistingType('type-1')), isEmpty);
    });

    test('a typed name gives the questions of the type it matches', () async {
      expect(await repo.questionsFor(NewTypeName('  SEIZURE ')), builtInEventTypes[2].questions);
    });

    test('a typed name matching no type gives none and saves nothing', () async {
      expect(await repo.questionsFor(NewTypeName('Ear shaking')), isEmpty);
      expect(await db.query('event_types'), isEmpty);
    });
  });

  group('remove', () {
    test(
      '001-FR-004: removing a custom type takes it off the lists and leaves its events alone',
      () async {
        await save(NewTypeName('Ear shaking'));
        await db.insert('pets', {
          'id': 'pet-1',
          'name': 'Biscuit',
          'species': 'dog',
          'created_at': 0,
        });
        await db.insert('events', {
          'id': 'event-1',
          'pet_id': 'pet-1',
          'type_id': 'type-1',
          'occurred_at': 1000,
          'created_at': 1000,
          'updated_at': 1000,
        });
        final eventsBefore = await db.query('events');

        await repo.remove('type-1');

        expect((await row('type-1'))['removed'], 1);
        expect(await repo.watchCustom().first, isEmpty);
        expect(names(await repo.watchOffered().first), builtInNames);
        expect(await db.query('events'), eventsBefore);
      },
    );
  });

  group('lists', () {
    test('001-FR-004: offered lists the built-ins in their order, then custom types not removed, by name ignoring case', () async {
      for (final name in ['Zoomies', 'apple', 'Bark', 'hiccups']) {
        await save(NewTypeName(name));
      }
      await repo.remove('type-4');

      expect(names(await repo.watchOffered().first), [...builtInNames, 'apple', 'Bark', 'Zoomies']);
      expect(names(await repo.watchCustom().first), ['apple', 'Bark', 'Zoomies']);
    });

    test('custom lists only custom types', () async {
      expect(await repo.watchCustom().first, isEmpty);
    });
  });

  group('streams', () {
    test('each stream emits on listen and again after each change, on every open stream', () async {
      final offered = StreamIterator(repo.watchOffered());
      final custom = StreamIterator(repo.watchCustom());
      addTearDown(() => [offered, custom].map((s) => s.cancel()).wait);

      expect(names(await next(offered)), builtInNames);
      expect(await next(custom), isEmpty);

      await save(NewTypeName('Ear shaking'));
      expect(names(await next(offered)), [...builtInNames, 'Ear shaking']);
      expect(names(await next(custom)), ['Ear shaking']);

      await repo.remove('type-1');
      expect(names(await next(offered)), builtInNames);
      expect(await next(custom), isEmpty);
    });
  });
}
