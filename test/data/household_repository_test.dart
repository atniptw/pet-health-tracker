import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pet_health_tracker/data/household.dart';
import 'package:pet_health_tracker/data/household_repository.dart';
import 'package:pet_health_tracker/data/invite_code.dart';

class MockWriteBatch extends Mock implements WriteBatch {}

/// A Firestore whose first batch commits fail, one per code in [errors].
class RefusingFirestore extends FakeFirebaseFirestore {
  RefusingFirestore(this.errors);

  final List<String> errors;

  @override
  WriteBatch batch() {
    if (errors.isEmpty) return super.batch();
    final batch = MockWriteBatch();
    when(batch.commit)
        .thenThrow(FirebaseException(plugin: 'cloud_firestore', code: errors.removeAt(0)));
    return batch;
  }
}

void main() {
  late FakeFirebaseFirestore firestore;
  late HouseholdRepository repository;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    repository = HouseholdRepository(firestore);
  });

  group('createHousehold', () {
    test('writes the fields the security rules require', () async {
      await repository.createHousehold(name: 'Home', ownerUid: 'u1', ownerName: 'Tom');

      final docs = (await firestore.collection('households').get()).docs;
      expect(docs, hasLength(1));
      final data = docs.single.data();
      expect(
        data.keys,
        unorderedEquals(<String>[
          'name',
          'memberIds',
          'adminIds',
          'createdAt',
          'updatedAt',
          'schemaVersion',
        ]),
      );
      expect(data['name'], 'Home');
      expect(data['memberIds'], ['u1']);
      expect(data['adminIds'], ['u1']);
      expect(data['createdAt'], isA<Timestamp>());
      expect(data['updatedAt'], isA<Timestamp>());
      expect(data['schemaVersion'], 1);
    });

    test("writes the owner's member doc with their name", () async {
      await repository.createHousehold(name: 'Home', ownerUid: 'u1', ownerName: 'Tom');

      final household = (await firestore.collection('households').get()).docs.single;
      final member = await household.reference.collection('members').doc('u1').get();
      final data = member.data()!;
      expect(
        data.keys,
        unorderedEquals(<String>['name', 'createdAt', 'updatedAt', 'schemaVersion']),
      );
      expect(data['name'], 'Tom');
      expect(data['createdAt'], isA<Timestamp>());
      expect(data['updatedAt'], isA<Timestamp>());
      expect(data['schemaVersion'], 1);
    });
  });

  group('watchMyHouseholds', () {
    test('emits nothing when the user is in no household', () async {
      expect(await repository.watchMyHouseholds('u1').first, isEmpty);
    });

    test("emits the user's households sorted by name", () async {
      await repository.createHousehold(name: 'the Den', ownerUid: 'u1', ownerName: 'Tom');
      await repository.createHousehold(name: 'Cabin', ownerUid: 'u1', ownerName: 'Tom');

      final households = await repository.watchMyHouseholds('u1').first;

      expect(households.map((h) => h.name), ['Cabin', 'the Den']);
      expect(households.first, isA<Household>());
      expect(households.first.memberIds, ['u1']);
      expect(households.first.adminIds, ['u1']);
    });

    test("does not emit someone else's household", () async {
      await repository.createHousehold(name: 'Theirs', ownerUid: 'u2', ownerName: 'Sam');

      expect(await repository.watchMyHouseholds('u1').first, isEmpty);
    });

    test('emits again when the user creates a household', () async {
      final emissions = repository.watchMyHouseholds('u1').map((h) => h.map((e) => e.name));

      final expectation = expectLater(
        emissions,
        emitsInOrder(<Matcher>[
          isEmpty,
          equals(['Home']),
        ]),
      );
      await repository.createHousehold(name: 'Home', ownerUid: 'u1', ownerName: 'Tom');
      await expectation;
    });
  });

  group('member names', () {
    Future<String> seedHousehold() async {
      final ref = await firestore.collection('households').add({
        'name': 'Home',
        'memberIds': ['u1'],
        'adminIds': ['u1'],
      });
      return ref.id;
    }

    test('a member with no member doc is missing a name', () async {
      final householdId = await seedHousehold();

      expect(await repository.watchNameMissing(householdId: householdId, uid: 'u1').first, isTrue);
    });

    test('the creator is not missing a name', () async {
      await repository.createHousehold(name: 'Home', ownerUid: 'u1', ownerName: 'Tom');
      final householdId = (await firestore.collection('households').get()).docs.single.id;

      expect(await repository.watchNameMissing(householdId: householdId, uid: 'u1').first, isFalse);
    });

    test('adding a name writes the member doc and clears missing', () async {
      final householdId = await seedHousehold();
      final missing = repository.watchNameMissing(householdId: householdId, uid: 'u1');
      final expectation = expectLater(missing, emitsInOrder(<bool>[true, false]));

      await repository.addMemberName(householdId: householdId, uid: 'u1', name: 'Tom');
      await expectation;

      final data = (await firestore.doc('households/$householdId/members/u1').get()).data()!;
      expect(
        data.keys,
        unorderedEquals(<String>['name', 'createdAt', 'updatedAt', 'schemaVersion']),
      );
      expect(data['name'], 'Tom');
      expect(data['schemaVersion'], 1);
    });

    test("lists every member's name by uid", () async {
      final householdId = await seedHousehold();
      await repository.addMemberName(householdId: householdId, uid: 'u1', name: 'Tom');
      await repository.addMemberName(householdId: householdId, uid: 'u2', name: 'Sam');

      expect(await repository.watchMemberNames(householdId).first, {'u1': 'Tom', 'u2': 'Sam'});
    });
  });

  group('joinHousehold', () {
    const code = 'acorn tulip shelf';
    final now = DateTime(2026, 10, 10, 12);

    Future<void> seed(FakeFirebaseFirestore firestore, {DateTime? invitedAt}) async {
      await firestore.doc('households/h1').set({
        'name': 'The Den',
        'memberIds': ['admin'],
        'adminIds': ['admin'],
      });
      await firestore.doc('invites/${inviteIdFor(code)}').set({
        'householdId': 'h1',
        'createdBy': 'admin',
        'createdAt': Timestamp.fromDate(invitedAt ?? DateTime(2026, 10, 9)),
        'schemaVersion': 1,
      });
    }

    test('adds the user as a member with their name and the invite used', () async {
      await seed(firestore);

      final householdId = await repository.joinHousehold(
        code: code,
        uid: 'u1',
        name: 'Tom',
        now: () => now,
      );

      expect(householdId, 'h1');
      final household = (await firestore.doc('households/h1').get()).data()!;
      expect(household['memberIds'], ['admin', 'u1']);
      expect(household['adminIds'], ['admin']);
      expect(household['updatedAt'], isA<Timestamp>());
      final member = (await firestore.doc('households/h1/members/u1').get()).data()!;
      expect(
        member.keys,
        unorderedEquals(<String>['name', 'inviteId', 'createdAt', 'updatedAt', 'schemaVersion']),
      );
      expect(member['name'], 'Tom');
      expect(member['inviteId'], inviteIdFor(code));
    });

    test('ignores trailing spaces in the code', () async {
      await seed(firestore);

      expect(
        await repository.joinHousehold(code: '$code  ', uid: 'u1', name: 'Tom', now: () => now),
        'h1',
      );
    });

    test('refuses a code with no invite', () async {
      await seed(firestore);

      await expectLater(
        repository.joinHousehold(code: 'Acorn tulip shelf', uid: 'u1', name: 'Tom', now: () => now),
        throwsA(isA<InviteNotFoundException>()),
      );
      expect((await firestore.doc('households/h1').get()).data()!['memberIds'], ['admin']);
    });

    test('refuses an expired invite', () async {
      await seed(firestore, invitedAt: now.subtract(inviteLifetime));

      await expectLater(
        repository.joinHousehold(code: code, uid: 'u1', name: 'Tom', now: () => now),
        throwsA(isA<InviteNotFoundException>()),
      );
    });

    test('someone already in the household just gets its ID', () async {
      await seed(firestore);

      expect(
        await repository.joinHousehold(code: code, uid: 'admin', name: 'Tom', now: () => now),
        'h1',
      );
      expect((await firestore.doc('households/h1/members/admin').get()).exists, isFalse);
    });

    test('a former member rejoins by merging into their kept doc', () async {
      final refusing = RefusingFirestore(['permission-denied']);
      await seed(refusing);
      await refusing.doc('households/h1/members/u1').set({
        'name': 'Tom',
        'createdAt': Timestamp.fromDate(DateTime(2026)),
        'schemaVersion': 1,
      });

      await HouseholdRepository(refusing)
          .joinHousehold(code: code, uid: 'u1', name: 'Dad', now: () => now);

      final member = (await refusing.doc('households/h1/members/u1').get()).data()!;
      expect(member['name'], 'Dad');
      expect(member['inviteId'], inviteIdFor(code));
      expect(member['createdAt'], Timestamp.fromDate(DateTime(2026)));
      expect((await refusing.doc('households/h1').get()).data()!['memberIds'], ['admin', 'u1']);
    });

    test('refused twice means the invite stopped working', () async {
      final refusing = RefusingFirestore(['permission-denied', 'permission-denied']);
      await seed(refusing);

      await expectLater(
        HouseholdRepository(refusing)
            .joinHousehold(code: code, uid: 'u1', name: 'Tom', now: () => now),
        throwsA(isA<InviteNotFoundException>()),
      );
    });

    test('other errors pass through', () async {
      for (final errors in [
        ['unavailable'],
        ['permission-denied', 'unavailable'],
      ]) {
        final failing = RefusingFirestore(errors);
        await seed(failing);

        await expectLater(
          HouseholdRepository(failing)
              .joinHousehold(code: code, uid: 'u1', name: 'Tom', now: () => now),
          throwsA(isA<FirebaseException>().having((e) => e.code, 'code', 'unavailable')),
          reason: '$errors',
        );
      }
    });

    test('says what to do about a code that matches nothing', () {
      expect(
        const InviteNotFoundException().toString(),
        'No household found for that code. Check the spelling, or ask for a new code.',
      );
    });
  });
}
