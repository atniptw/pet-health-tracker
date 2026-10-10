import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_health_tracker/core/firebase_providers.dart';
import 'package:pet_health_tracker/data/invite_code_store.dart';
import 'package:pet_health_tracker/data/invite_repository.dart';
import 'package:pet_health_tracker/features/household/invite_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the invite repository uses the app Firestore', () {
    final container = ProviderContainer(
      overrides: [firestoreProvider.overrideWithValue(FakeFirebaseFirestore())],
    );
    addTearDown(container.dispose);

    expect(container.read(inviteRepositoryProvider), isA<InviteRepository>());
  });

  test('invite codes are kept in secure storage', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(inviteCodeStoreProvider), isA<InviteCodeStore>());
  });

  test('sharing opens the platform share sheet with the text and anchor', () async {
    const channel = MethodChannel('dev.fluttercommunity.plus/share');
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (call) async {
        calls.add(call);
        return 'shared';
      },
    );
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(shareTextProvider)('acorn tulip shelf', const Rect.fromLTWH(1, 2, 3, 4));

    expect(calls.single.method, 'share');
    final arguments = calls.single.arguments as Map;
    expect(arguments['text'], 'acorn tulip shelf');
    expect(arguments['originX'], 1);
    expect(arguments['originWidth'], 3);
  });
}
