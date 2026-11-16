import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pet_health_tracker/data/local/local_pet_repository.dart';
import 'package:pet_health_tracker/domain/pet.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../support/test_database.dart';

/// 2026-11-14 12:00 in America/Chicago, where the tests run.
final now = DateTime(2026, 11, 14, 12);

List<String> names(List<Pet> pets) => [for (final pet in pets) pet.name];

/// The next value [stream] emits.
Future<T> next<T>(StreamIterator<T> stream) async {
  expect(await stream.moveNext(), isTrue);
  return stream.current;
}

void main() {
  late Database db;
  late LocalPetRepository repo;

  setUp(() async {
    db = await openTestDatabase();
    var id = 0;
    repo = LocalPetRepository(db, () => now, () => 'pet-${++id}');
  });

  tearDown(() => db.close());

  group('add', () {
    test(
      '001-FR-001: adds an active pet with a new id, the trimmed name and its species',
      () async {
        final pet = await repo.add(name: '  Biscuit ', species: Species.dog);

        expect(
          pet,
          Pet(id: 'pet-1', name: 'Biscuit', species: Species.dog, createdAt: now.toUtc()),
        );
        expect(await repo.watch('pet-1').first, pet);
      },
    );

    test('001-FR-001: createdAt is the clock time in UTC, read back as the same instant', () async {
      await repo.add(name: 'Biscuit', species: Species.dog);

      final read = (await repo.watch('pet-1').first)!;
      expect(read.createdAt, DateTime.utc(2026, 11, 14, 18));
      expect(read.createdAt.isUtc, isTrue);
    });

    test('001-FR-001: a name empty after trimming or over 40 characters is refused', () async {
      expect(() => repo.add(name: '   ', species: Species.cat), throwsArgumentError);
      expect(() => repo.add(name: 'a' * 41, species: Species.cat), throwsArgumentError);
      expect(await repo.watchActive().first, isEmpty);
    });

    test('the refusal does not repeat the typed name', () async {
      final typed = 'Mister Whiskers ' * 3;
      await expectLater(
        repo.add(name: typed, species: Species.cat),
        throwsA(
          isA<ArgumentError>().having((e) => e.toString(), 'message', isNot(contains('Whiskers'))),
        ),
      );
    });
  });

  group('update', () {
    test('001-FR-001: changes the name and species, trimmed', () async {
      await repo.add(name: 'Biscuit', species: Species.dog);

      await repo.update('pet-1', name: ' Mochi  ', species: Species.cat);

      final pet = (await repo.watch('pet-1').first)!;
      expect(pet.name, 'Mochi');
      expect(pet.species, Species.cat);
    });

    test(
      '001-US3-S2: renaming or changing species keeps the id, so its events stay with it',
      () async {
        final added = await repo.add(name: 'Biscuit', species: Species.dog);
        await db.insert('events', {
          'id': 'event-1',
          'pet_id': 'pet-1',
          'type_id': 'vomiting',
          'occurred_at': 1000,
          'created_at': 1000,
          'updated_at': 1000,
        });

        await repo.update('pet-1', name: 'Mochi', species: Species.other);

        expect(
          await repo.watch('pet-1').first,
          added.copyWith(name: 'Mochi', species: Species.other),
        );
        final events = await db.query('events', where: 'pet_id = ?', whereArgs: ['pet-1']);
        expect(events.map((e) => e['id']), ['event-1']);
      },
    );

    test('001-FR-001: a name empty after trimming or over 40 characters is refused and nothing changes', () async {
      await repo.add(name: 'Biscuit', species: Species.dog);

      expect(() => repo.update('pet-1', name: '', species: Species.cat), throwsArgumentError);
      expect(() => repo.update('pet-1', name: 'a' * 41, species: Species.cat), throwsArgumentError);
      final pet = (await repo.watch('pet-1').first)!;
      expect(pet.name, 'Biscuit');
      expect(pet.species, Species.dog);
    });
  });

  group('setArchived', () {
    test('archiving moves a pet to the archived list, restoring moves it back', () async {
      await repo.add(name: 'Biscuit', species: Species.dog);

      await repo.setArchived('pet-1', true);
      expect(await repo.watchActive().first, isEmpty);
      expect(names(await repo.watchArchived().first), ['Biscuit']);
      expect((await repo.watch('pet-1').first)!.archived, isTrue);

      await repo.setArchived('pet-1', false);
      expect(names(await repo.watchActive().first), ['Biscuit']);
      expect(await repo.watchArchived().first, isEmpty);
      expect((await repo.watch('pet-1').first)!.archived, isFalse);
    });
  });

  group('lists', () {
    test('active and archived pets are each listed by name, ignoring case', () async {
      for (final name in ['mochi', 'Biscuit', 'Ziggy', 'apple', 'Élan', 'élan']) {
        await repo.add(name: name, species: Species.cat);
      }
      await repo.setArchived('pet-3', true);
      await repo.setArchived('pet-4', true);

      expect(names(await repo.watchActive().first), ['Biscuit', 'mochi', 'Élan', 'élan']);
      expect(names(await repo.watchArchived().first), ['apple', 'Ziggy']);
    });

    test('pets with the same name keep the same order on every emit', () async {
      final ids = ['pet-c', 'pet-a', 'pet-b'].iterator;
      repo = LocalPetRepository(db, () => now, () => (ids..moveNext()).current);
      await repo.add(name: 'max', species: Species.dog);
      await repo.add(name: 'Max', species: Species.cat);
      await repo.add(name: 'Max', species: Species.other);
      final active = StreamIterator(repo.watchActive());
      addTearDown(active.cancel);
      List<String> idsOf(List<Pet> pets) => [for (final pet in pets) pet.id];

      expect(idsOf(await next(active)), ['pet-a', 'pet-b', 'pet-c']);
      await repo.update('pet-c', name: 'max', species: Species.cat);
      expect(idsOf(await next(active)), ['pet-a', 'pet-b', 'pet-c']);
    });

    test('watch of an unknown id emits null', () async {
      expect(await repo.watch('nobody').first, isNull);
    });
  });

  group('streams', () {
    test('each stream emits on listen and again after each write, on every open stream', () async {
      final active = StreamIterator(repo.watchActive());
      final archived = StreamIterator(repo.watchArchived());
      final one = StreamIterator(repo.watch('pet-1'));
      addTearDown(() => [active, archived, one].map((s) => s.cancel()).wait);

      expect(await next(active), isEmpty);
      expect(await next(archived), isEmpty);
      expect(await next(one), isNull);

      await repo.add(name: 'Biscuit', species: Species.dog);
      expect(names(await next(active)), ['Biscuit']);
      expect(await next(archived), isEmpty);
      expect((await next(one))!.name, 'Biscuit');

      await repo.update('pet-1', name: 'Mochi', species: Species.dog);
      expect(names(await next(active)), ['Mochi']);
      expect(await next(archived), isEmpty);
      expect((await next(one))!.name, 'Mochi');

      await repo.setArchived('pet-1', true);
      expect(await next(active), isEmpty);
      expect(names(await next(archived)), ['Mochi']);
      expect((await next(one))!.archived, isTrue);
    });

    test('a write after a stream is cancelled still succeeds', () async {
      final active = StreamIterator(repo.watchActive());
      expect(await next(active), isEmpty);
      await active.cancel();

      await repo.add(name: 'Biscuit', species: Species.dog);

      expect(names(await repo.watchActive().first), ['Biscuit']);
    });

    test('a failed read is reported on the stream', () async {
      await db.close();

      expect(repo.watchActive(), emitsError(isA<DatabaseException>()));
    });
  });
}
