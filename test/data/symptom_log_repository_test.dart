import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_health_tracker/data/symptom_log_repository.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late SymptomLogRepository repository;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    repository = SymptomLogRepository(firestore);
  });

  CollectionReference<Map<String, dynamic>> logs() => firestore
      .collection('households')
      .doc('h1')
      .collection('pets')
      .doc('p1')
      .collection('symptomLogs');

  group('addOtherLog', () {
    test('writes only the required fields when there are no notes', () async {
      await repository.addOtherLog(
        householdId: 'h1',
        petId: 'p1',
        createdBy: 'user-1',
        title: 'Ate a sock',
        occurredAt: DateTime.utc(2026, 10, 5, 14, 30),
      );

      final data = (await logs().get()).docs.single.data();
      expect(
        data.keys,
        unorderedEquals(<String>[
          'symptom',
          'title',
          'createdBy',
          'occurredAt',
          'createdAt',
          'updatedAt',
          'schemaVersion',
        ]),
      );
      expect(data['symptom'], 'other');
      expect(data['title'], 'Ate a sock');
      expect(data['createdBy'], 'user-1');
      expect((data['occurredAt'] as Timestamp).toDate().toUtc(), DateTime.utc(2026, 10, 5, 14, 30));
      expect(data['createdAt'], isA<Timestamp>());
      expect(data['updatedAt'], isA<Timestamp>());
      expect(data['schemaVersion'], 1);
    });

    test('writes notes when given', () async {
      await repository.addOtherLog(
        householdId: 'h1',
        petId: 'p1',
        createdBy: 'user-1',
        title: 'Ate a sock',
        occurredAt: DateTime(2026, 10, 5),
        notes: 'Some fabric missing',
      );

      expect((await logs().get()).docs.single.data()['notes'], 'Some fabric missing');
    });

    test('leaves out blank notes', () async {
      await repository.addOtherLog(
        householdId: 'h1',
        petId: 'p1',
        createdBy: 'user-1',
        title: 'Ate a sock',
        occurredAt: DateTime(2026, 10, 5),
        notes: '',
      );

      expect((await logs().get()).docs.single.data().containsKey('notes'), isFalse);
    });
  });

  group('updateOtherLog', () {
    Future<String> addLog({String? notes}) async {
      await repository.addOtherLog(
        householdId: 'h1',
        petId: 'p1',
        createdBy: 'user-1',
        title: 'Ate a sock',
        occurredAt: DateTime.utc(2026, 10, 5, 14, 30),
        notes: notes,
      );
      return (await logs().get()).docs.single.id;
    }

    test('changes the title, time and notes, and keeps the author and createdAt', () async {
      final logId = await addLog();
      final createdAt = (await logs().doc(logId).get()).data()!['createdAt'];

      await repository.updateOtherLog(
        householdId: 'h1',
        petId: 'p1',
        logId: logId,
        title: 'Ate two socks',
        occurredAt: DateTime.utc(2026, 10, 4, 9),
        notes: 'Both from the laundry',
      );

      final data = (await logs().doc(logId).get()).data()!;
      expect(data['title'], 'Ate two socks');
      expect((data['occurredAt'] as Timestamp).toDate().toUtc(), DateTime.utc(2026, 10, 4, 9));
      expect(data['notes'], 'Both from the laundry');
      expect(data['symptom'], 'other');
      expect(data['createdBy'], 'user-1');
      expect(data['createdAt'], createdAt);
      expect(data['updatedAt'], isA<Timestamp>());
      expect(data['schemaVersion'], 1);
    });

    test('deletes notes that were cleared', () async {
      final logId = await addLog(notes: 'Some fabric missing');

      await repository.updateOtherLog(
        householdId: 'h1',
        petId: 'p1',
        logId: logId,
        title: 'Ate a sock',
        occurredAt: DateTime(2026, 10, 5),
        notes: '',
      );

      expect((await logs().doc(logId).get()).data()!.containsKey('notes'), isFalse);
    });
  });

  group('watchLogs', () {
    test("emits the pet's logs, most recent first", () async {
      Future<void> add(String title, DateTime occurredAt) => repository.addOtherLog(
        householdId: 'h1',
        petId: 'p1',
        createdBy: 'user-1',
        title: title,
        occurredAt: occurredAt,
      );
      await add('Morning', DateTime(2026, 10, 5, 8));
      await add('Evening', DateTime(2026, 10, 5, 20));
      await add('Yesterday', DateTime(2026, 10, 4, 12));

      final result = await repository.watchLogs(householdId: 'h1', petId: 'p1').first;

      expect(result.map((log) => log.title), ['Evening', 'Morning', 'Yesterday']);
      expect(result.first.occurredAt, DateTime(2026, 10, 5, 20));
      expect(result.first.symptom, 'other');
      expect(result.first.createdBy, 'user-1');
    });

    test('reads notes and answers, and ignores other pets', () async {
      await logs().doc('l1').set({
        'symptom': 'vomit',
        'createdBy': 'user-2',
        'answers': {'blood': true},
        'occurredAt': Timestamp.fromDate(DateTime(2026, 10, 5)),
        'notes': 'After breakfast',
        'schemaVersion': 1,
      });
      await firestore
          .collection('households')
          .doc('h1')
          .collection('pets')
          .doc('p2')
          .collection('symptomLogs')
          .add({
            'symptom': 'other',
            'title': 'Not mine',
            'createdBy': 'user-1',
            'occurredAt': Timestamp.fromDate(DateTime(2026, 10, 5)),
            'schemaVersion': 1,
          });

      final log = (await repository.watchLogs(householdId: 'h1', petId: 'p1').first).single;

      expect(log.id, 'l1');
      expect(log.symptom, 'vomit');
      expect(log.title, isNull);
      expect(log.notes, 'After breakfast');
      expect(log.answers, {'blood': true});
    });
  });
}
