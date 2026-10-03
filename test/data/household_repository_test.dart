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
      await repository.createHousehold(name: 'Home', ownerUid: 'u1');

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
  });

  group('watchMyHousehold', () {
    test('emits null when the user is in no household', () async {
      expect(await repository.watchMyHousehold('u1').first, isNull);
    });

    test("emits the user's household", () async {
      await repository.createHousehold(name: 'Home', ownerUid: 'u1');

      final household = await repository.watchMyHousehold('u1').first;

      expect(household, isA<Household>());
      expect(household!.name, 'Home');
      expect(household.memberIds, ['u1']);
      expect(household.adminIds, ['u1']);
    });

    test("does not emit someone else's household", () async {
      await repository.createHousehold(name: 'Theirs', ownerUid: 'u2');

      expect(await repository.watchMyHousehold('u1').first, isNull);
    });

    test('emits again when the user creates a household', () async {
      final emissions = repository.watchMyHousehold('u1').map((h) => h?.name);

      final expectation = expectLater(emissions, emitsInOrder(<String?>[null, 'Home']));
      await repository.createHousehold(name: 'Home', ownerUid: 'u1');
      await expectation;
    });
  });
}
