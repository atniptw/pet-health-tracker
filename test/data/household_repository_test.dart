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

/// A Firestore that counts the batches made from it.
class CountingFirestore extends FakeFirebaseFirestore {
  int batches = 0;

  @override
  WriteBatch batch() {
    batches++;
    return super.batch();
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
          'ownerId',
          'createdAt',
          'updatedAt',
          'schemaVersion',
        ]),
      );
      expect(data['name'], 'Home');
      expect(data['memberIds'], ['u1']);
      expect(data['adminIds'], ['u1']);
      expect(data['ownerId'], 'u1');
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
      expect(households.first.ownerId, 'u1');
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
        'ownerId': 'u1',
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

  test('renaming changes only the name and stamps updatedAt', () async {
    await firestore.doc('households/h1').set({
      'name': 'The Den',
      'memberIds': ['admin', 'u1'],
      'adminIds': ['admin'],
      'ownerId': 'admin',
    });

    await repository.renameHousehold(householdId: 'h1', name: 'The Burrow');

    final household = (await firestore.doc('households/h1').get()).data()!;
    expect(household['name'], 'The Burrow');
    expect(household['memberIds'], ['admin', 'u1']);
    expect(household['adminIds'], ['admin']);
    expect(household['updatedAt'], isA<Timestamp>());
  });

  test('leaving removes only the user from the members, and deletes their name', () async {
    await firestore.doc('households/h1').set({
      'name': 'The Den',
      'memberIds': ['admin', 'u1'],
      'adminIds': ['admin'],
      'ownerId': 'admin',
    });
    await firestore.doc('households/h1/members/u1').set({'name': 'Tom'});

    await repository.leaveHousehold(householdId: 'h1', uid: 'u1');

    final household = (await firestore.doc('households/h1').get()).data()!;
    expect(household['memberIds'], ['admin']);
    expect(household['adminIds'], ['admin']);
    expect(household['updatedAt'], isA<Timestamp>());
    expect((await firestore.doc('households/h1/members/u1').get()).exists, isFalse);
  });

  test('an admin who leaves stops being an admin', () async {
    await firestore.doc('households/h1').set({
      'name': 'The Den',
      'memberIds': ['admin', 'u1'],
      'adminIds': ['admin', 'u1'],
      'ownerId': 'admin',
    });

    await repository.leaveHousehold(householdId: 'h1', uid: 'u1');

    final household = (await firestore.doc('households/h1').get()).data()!;
    expect(household['memberIds'], ['admin']);
    expect(household['adminIds'], ['admin']);
  });

  group('removeMember', () {
    setUp(() async {
      await firestore.doc('households/h1').set({
        'name': 'The Den',
        'memberIds': ['owner', 'admin', 'u1', 'u2'],
        'adminIds': ['owner', 'admin'],
        'ownerId': 'owner',
      });
      await firestore.doc('households/h1/members/u1').set({'name': 'Tom'});
      await firestore.doc('households/h1/members/u2').set({'name': 'Sam'});
      await firestore.doc('invites/invite-h1').set({'householdId': 'h1'});
      await firestore.doc('invites/invite-h2').set({'householdId': 'h2'});
    });

    test(
      "takes the person out of the members, deletes their name and the household's invite",
      () async {
        await repository.removeMember(householdId: 'h1', uid: 'u1');

        final household = (await firestore.doc('households/h1').get()).data()!;
        expect(household['memberIds'], ['owner', 'admin', 'u2']);
        expect(household['adminIds'], ['owner', 'admin']);
        expect(household['updatedAt'], isA<Timestamp>());
        expect((await firestore.doc('households/h1/members/u1').get()).exists, isFalse);
        expect((await firestore.doc('households/h1/members/u2').get()).exists, isTrue);
        expect((await firestore.doc('invites/invite-h1').get()).exists, isFalse);
        expect((await firestore.doc('invites/invite-h2').get()).exists, isTrue);
      },
    );

    test('an admin who is removed stops being an admin', () async {
      await repository.removeMember(householdId: 'h1', uid: 'admin');

      final household = (await firestore.doc('households/h1').get()).data()!;
      expect(household['memberIds'], ['owner', 'u1', 'u2']);
      expect(household['adminIds'], ['owner']);
    });

    test('works when the household has no invite', () async {
      await firestore.doc('invites/invite-h1').delete();

      await repository.removeMember(householdId: 'h1', uid: 'u1');

      final household = (await firestore.doc('households/h1').get()).data()!;
      expect(household['memberIds'], ['owner', 'admin', 'u2']);
    });
  });

  group('roles', () {
    setUp(() async {
      await firestore.doc('households/h1').set({
        'name': 'The Den',
        'memberIds': ['owner', 'admin', 'u1'],
        'adminIds': ['owner', 'admin'],
        'ownerId': 'owner',
      });
    });

    test('making a member an admin adds only them to the admins', () async {
      await repository.makeAdmin(householdId: 'h1', uid: 'u1');

      final household = (await firestore.doc('households/h1').get()).data()!;
      expect(household['adminIds'], ['owner', 'admin', 'u1']);
      expect(household['memberIds'], ['owner', 'admin', 'u1']);
      expect(household['ownerId'], 'owner');
      expect(household['updatedAt'], isA<Timestamp>());
    });

    test('taking admin away keeps them a member', () async {
      await repository.removeAdmin(householdId: 'h1', uid: 'admin');

      final household = (await firestore.doc('households/h1').get()).data()!;
      expect(household['adminIds'], ['owner']);
      expect(household['memberIds'], ['owner', 'admin', 'u1']);
      expect(household['updatedAt'], isA<Timestamp>());
    });
  });

  test('transferring ownership makes the member the owner and an admin, keeping the old owner an admin', () async {
    await firestore.doc('households/h1').set({
      'name': 'The Den',
      'memberIds': ['admin', 'u1'],
      'adminIds': ['admin'],
      'ownerId': 'admin',
    });

    await repository.transferOwnership(householdId: 'h1', toUid: 'u1');

    final household = (await firestore.doc('households/h1').get()).data()!;
    expect(household['ownerId'], 'u1');
    expect(household['adminIds'], ['admin', 'u1']);
    expect(household['memberIds'], ['admin', 'u1']);
    expect(household['updatedAt'], isA<Timestamp>());
  });

  group('deleteHousehold', () {
    Future<void> seed(FakeFirebaseFirestore firestore, {int logs = 1}) async {
      for (final id in ['h1', 'h2']) {
        await firestore.doc('households/$id').set({
          'name': id,
          'memberIds': ['admin', 'u1'],
          'adminIds': ['admin'],
          'ownerId': 'admin',
        });
        await firestore.doc('households/$id/members/admin').set({'name': 'Ann'});
        await firestore.doc('households/$id/members/u1').set({'name': 'Tom'});
        await firestore.doc('households/$id/pets/p1').set({'name': 'Boogie'});
        await firestore.doc('households/$id/pets/p2').set({'name': 'Pootz', 'archivedAt': 1});
        await firestore.doc('households/$id/pets/p1/medications/m1').set({'name': 'Pill'});
        for (var i = 0; i < logs; i++) {
          await firestore.doc('households/$id/pets/p2/symptomLogs/l$i').set({'symptom': 'other'});
        }
        await firestore.doc('invites/invite-$id').set({'householdId': id});
      }
    }

    Future<List<String>> paths(FakeFirebaseFirestore firestore, String householdId) async {
      final household = firestore.doc('households/$householdId');
      return [
        if ((await household.get()).exists) household.path,
        for (final collection in ['members', 'pets'])
          ...(await household.collection(collection).get()).docs.map((d) => d.reference.path),
        for (final pet in ['p1', 'p2'])
          for (final collection in ['symptomLogs', 'medications'])
            ...(await household.collection('pets/$pet/$collection').get()).docs.map(
              (d) => d.reference.path,
            ),
        ...(await firestore
                .collection('invites')
                .where('householdId', isEqualTo: householdId)
                .get())
            .docs
            .map((d) => d.reference.path),
      ];
    }

    test('deletes the household with its names, pets, logs, medications and invite', () async {
      await seed(firestore);
      final otherBefore = await paths(firestore, 'h2');

      await repository.deleteHousehold('h1');

      expect(await paths(firestore, 'h1'), isEmpty);
      expect(await paths(firestore, 'h2'), otherBefore);
    });

    test('splits the deletes into batches of at most 500', () async {
      final counting = CountingFirestore();
      await seed(counting, logs: 499);

      await HouseholdRepository(counting).deleteHousehold('h1');

      expect(await paths(counting, 'h1'), isEmpty);
      // 499 logs, a medication, 2 pets and an invite, then the names and the household.
      expect(counting.batches, 3);
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
        'ownerId': 'admin',
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
