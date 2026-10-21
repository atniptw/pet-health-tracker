import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pet_health_tracker/core/firebase_providers.dart';
import 'package:pet_health_tracker/data/household_repository.dart';
import 'package:pet_health_tracker/features/auth/account_deletion.dart';
import 'package:pet_health_tracker/features/household/household_providers.dart';
import 'package:pet_health_tracker/features/household/invite_providers.dart';

import '../helpers.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late MockAuthRepository auth;
  late FakeLastHouseholdStore lastHouseholds;
  late FakeInviteCodeStore inviteCodes;
  late AccountDeletion deletion;

  Future<void> household(String id, {required String owner, List<String> others = const []}) async {
    await firestore.doc('households/$id').set({
      'name': id,
      'memberIds': [owner, ...others],
      'adminIds': [owner],
      'ownerId': owner,
    });
    for (final uid in [owner, ...others]) {
      await firestore.doc('households/$id/members/$uid').set({'name': uid});
    }
    await firestore.doc('households/$id/pets/p1').set({'name': 'Boogie'});
    await firestore.doc('households/$id/pets/p1/symptomLogs/l1').set({'createdBy': 'me'});
  }

  Future<Map<String, Object?>?> data(String path) async => (await firestore.doc(path).get()).data();

  setUp(() {
    firestore = FakeFirebaseFirestore();
    auth = MockAuthRepository();
    when(auth.reauthenticate).thenAnswer((_) async => 'apple-code');
    when(() => auth.deleteUser(appleAuthorizationCode: any(named: 'appleAuthorizationCode')))
        .thenAnswer((_) async {});
    lastHouseholds = FakeLastHouseholdStore()..saved['me'] = 'mine';
    inviteCodes = FakeInviteCodeStore()
      ..saved['me.mine'] = 'acorn tulip shelf'
      ..saved['you.theirs'] = 'plum otter lamp';
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        householdRepositoryProvider.overrideWithValue(HouseholdRepository(firestore)),
        lastHouseholdStoreProvider.overrideWithValue(lastHouseholds),
        inviteCodeStoreProvider.overrideWithValue(inviteCodes),
      ],
    );
    addTearDown(container.dispose);
    deletion = container.read(accountDeletionProvider);
  });

  test('leaves households the user is in, keeping their logs', () async {
    await household('theirs', owner: 'you', others: ['me']);

    await deletion.delete(uid: 'me', newOwners: const {});

    final theirs = await data('households/theirs');
    expect(theirs!['memberIds'], ['you']);
    expect(await data('households/theirs/members/me'), isNull);
    expect(await data('households/theirs/pets/p1/symptomLogs/l1'), isNotNull);
  });

  test('hands an owned household to the chosen member, then leaves it', () async {
    await household('mine', owner: 'me', others: ['you']);

    await deletion.delete(uid: 'me', newOwners: const {'mine': 'you'});

    final mine = await data('households/mine');
    expect(mine!['ownerId'], 'you');
    expect(mine['memberIds'], ['you']);
    expect(mine['adminIds'], ['you']);
    expect(await data('households/mine/members/me'), isNull);
  });

  test('deletes an owned household when chosen', () async {
    await household('mine', owner: 'me', others: ['you']);

    await deletion.delete(uid: 'me', newOwners: const {'mine': null});

    expect(await data('households/mine'), isNull);
    expect(await data('households/mine/pets/p1/symptomLogs/l1'), isNull);
  });

  test("forgets this phone's saved household and invite codes, then deletes the user", () async {
    await household('mine', owner: 'me');

    await deletion.delete(uid: 'me', newOwners: const {'mine': null});

    expect(lastHouseholds.saved, isEmpty);
    expect(inviteCodes.saved.keys, ['you.theirs']);
    verifyInOrder([
      auth.reauthenticate,
      () => auth.deleteUser(appleAuthorizationCode: 'apple-code'),
    ]);
  });

  test('changes nothing when an owned household has no choice', () async {
    await household('mine', owner: 'me', others: ['you']);
    await household('theirs', owner: 'you', others: ['me']);

    await expectLater(
      deletion.delete(uid: 'me', newOwners: const {}),
      throwsA(
        isA<OwnedHouseholdsChangedException>().having(
          (e) => '$e',
          'message',
          'Your households changed. Check them and try again.',
        ),
      ),
    );

    expect((await data('households/theirs'))!['memberIds'], ['you', 'me']);
    expect(await data('households/mine'), isNotNull);
    verifyNever(
      () => auth.deleteUser(appleAuthorizationCode: any(named: 'appleAuthorizationCode')),
    );
  });

  test('changes nothing when signing in again fails or is cancelled', () async {
    await household('theirs', owner: 'you', others: ['me']);
    when(auth.reauthenticate).thenThrow(Exception('cancelled'));

    await expectLater(deletion.delete(uid: 'me', newOwners: const {}), throwsException);

    expect((await data('households/theirs'))!['memberIds'], ['you', 'me']);
  });
}
