import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pet_health_tracker/data/invite.dart';
import 'package:pet_health_tracker/data/invite_code.dart';
import 'package:pet_health_tracker/data/invite_code_store.dart';

class MockFlutterSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  late MockFlutterSecureStorage storage;
  late InviteCodeStore store;

  setUp(() {
    storage = MockFlutterSecureStorage();
    store = InviteCodeStore(storage);
  });

  test('keys codes by account and household', () async {
    when(() => storage.read(key: 'inviteCode.u1.h1')).thenAnswer((_) async => 'acorn tulip shelf');
    when(
      () => storage.write(
        key: any(named: 'key'),
        value: any(named: 'value'),
      ),
    ).thenAnswer((_) async {});
    when(() => storage.delete(key: any(named: 'key'))).thenAnswer((_) async {});

    expect(await store.read(uid: 'u1', householdId: 'h1'), 'acorn tulip shelf');

    await store.write(uid: 'u1', householdId: 'h2', code: 'plum otter lamp');
    verify(() => storage.write(key: 'inviteCode.u1.h2', value: 'plum otter lamp')).called(1);

    await store.delete(uid: 'u2', householdId: 'h1');
    verify(() => storage.delete(key: 'inviteCode.u2.h1')).called(1);
  });

  group('savedCodeFor', () {
    Invite inviteFor(String code) =>
        Invite(id: inviteIdFor(code), householdId: 'h1', createdAt: DateTime(2026, 10, 9));

    test('is the saved code when it is the active invite', () {
      expect(
        savedCodeFor(inviteFor('acorn tulip shelf'), 'acorn tulip shelf'),
        'acorn tulip shelf',
      );
    });

    test('is null when the active invite was made from another code', () {
      expect(savedCodeFor(inviteFor('plum otter lamp'), 'acorn tulip shelf'), isNull);
    });

    test('is null when there is no active invite or no saved code', () {
      expect(savedCodeFor(null, 'acorn tulip shelf'), isNull);
      expect(savedCodeFor(inviteFor('acorn tulip shelf'), null), isNull);
    });
  });
}
