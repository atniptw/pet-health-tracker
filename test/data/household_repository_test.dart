import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_health_tracker/data/household.dart';
import 'package:pet_health_tracker/data/household_repository.dart';

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

  group('watchMyHousehold', () {
    test('emits null when the user is in no household', () async {
      expect(await repository.watchMyHousehold('u1').first, isNull);
    });

    test("emits the user's household", () async {
      await repository.createHousehold(name: 'Home', ownerUid: 'u1', ownerName: 'Tom');

      final household = await repository.watchMyHousehold('u1').first;

      expect(household, isA<Household>());
      expect(household!.name, 'Home');
      expect(household.memberIds, ['u1']);
      expect(household.adminIds, ['u1']);
    });

    test("does not emit someone else's household", () async {
      await repository.createHousehold(name: 'Theirs', ownerUid: 'u2', ownerName: 'Tom');

      expect(await repository.watchMyHousehold('u1').first, isNull);
    });

    test('emits again when the user creates a household', () async {
      final emissions = repository.watchMyHousehold('u1').map((h) => h?.name);

      final expectation = expectLater(emissions, emitsInOrder(<String?>[null, 'Home']));
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
  });
}
