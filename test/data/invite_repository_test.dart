import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_health_tracker/data/invite.dart';
import 'package:pet_health_tracker/data/invite_code.dart';
import 'package:pet_health_tracker/data/invite_repository.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late InviteRepository repository;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    repository = InviteRepository(firestore);
  });

  Future<void> seedInvite(String code, {String householdId = 'h1', required DateTime createdAt}) {
    return firestore.doc('invites/${inviteIdFor(code)}').set({
      'householdId': householdId,
      'createdBy': 'u1',
      'createdAt': Timestamp.fromDate(createdAt),
      'schemaVersion': 1,
    });
  }

  group('createInvite', () {
    test('stores only the hash of the code, with the fields the rules require', () async {
      await repository.createInvite(householdId: 'h1', createdBy: 'u1', code: 'acorn tulip shelf');

      final docs = (await firestore.collection('invites').get()).docs;
      expect(docs.single.id, inviteIdFor('acorn tulip shelf'));
      final data = docs.single.data();
      expect(
        data.keys,
        unorderedEquals(<String>['householdId', 'createdBy', 'createdAt', 'schemaVersion']),
      );
      expect(data['householdId'], 'h1');
      expect(data['createdBy'], 'u1');
      expect(data['createdAt'], isA<Timestamp>());
      expect(data['schemaVersion'], 1);
      expect(data.values, isNot(contains('acorn tulip shelf')));
    });

    test("replaces the household's old invite, leaving other households' alone", () async {
      await seedInvite('old code here', createdAt: DateTime.now());
      await seedInvite('their code here', householdId: 'h2', createdAt: DateTime.now());

      await repository.createInvite(householdId: 'h1', createdBy: 'u1', code: 'acorn tulip shelf');

      final ids = (await firestore.collection('invites').get()).docs.map((d) => d.id);
      expect(
        ids,
        unorderedEquals([inviteIdFor('acorn tulip shelf'), inviteIdFor('their code here')]),
      );
    });
  });

  group('watchActiveInvite', () {
    final now = DateTime(2026, 10, 10, 12);

    test('emits null when the household has no invite', () async {
      expect(await repository.watchActiveInvite('h1', now: () => now).first, isNull);
    });

    test('emits the unexpired invite with its expiry', () async {
      await seedInvite('acorn tulip shelf', createdAt: DateTime(2026, 10, 9));

      final invite = await repository.watchActiveInvite('h1', now: () => now).first;

      expect(invite, isA<Invite>());
      expect(invite!.id, inviteIdFor('acorn tulip shelf'));
      expect(invite.householdId, 'h1');
      expect(invite.expiresAt, DateTime(2026, 10, 16));
    });

    test('ignores invites 7 days old or older', () async {
      await seedInvite('acorn tulip shelf', createdAt: now.subtract(inviteLifetime));

      expect(await repository.watchActiveInvite('h1', now: () => now).first, isNull);
    });

    test("ignores other households' invites", () async {
      await seedInvite('acorn tulip shelf', householdId: 'h2', createdAt: DateTime(2026, 10, 9));

      expect(await repository.watchActiveInvite('h1', now: () => now).first, isNull);
    });

    test('emits the newest when there is more than one', () async {
      await seedInvite('older code here', createdAt: DateTime(2026, 10, 8));
      await seedInvite('newer code here', createdAt: DateTime(2026, 10, 9));

      final invite = await repository.watchActiveInvite('h1', now: () => now).first;

      expect(invite!.id, inviteIdFor('newer code here'));
    });

    test('treats a just-made invite as made now', () async {
      await repository.createInvite(householdId: 'h1', createdBy: 'u1', code: 'acorn tulip shelf');

      final invite = await repository.watchActiveInvite('h1').first;

      expect(invite!.isActiveAt(DateTime.now()), isTrue);
    });
  });

  test('a taken code says so', () {
    expect(const InviteCodeTakenException().toString(), 'That code is taken. Try another.');
  });
}
