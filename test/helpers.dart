import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pet_health_tracker/data/last_household_store.dart';
import 'package:pet_health_tracker/features/auth/auth_repository.dart';

class MockUser extends Mock implements User {}

class MockAuthRepository extends Mock implements AuthRepository {}

/// Keeps the last-opened household in memory instead of on the device.
class FakeLastHouseholdStore implements LastHouseholdStore {
  final saved = <String, String>{};

  @override
  Future<String?> read(String uid) async => saved[uid];

  @override
  Future<void> write(String uid, String householdId) async => saved[uid] = householdId;
}

MockUser fakeUser({String uid = 'user-1', String? displayName = 'Tom'}) {
  final user = MockUser();
  when(() => user.uid).thenReturn(uid);
  when(() => user.displayName).thenReturn(displayName);
  return user;
}

extension PumpApp on WidgetTester {
  /// Pumps [child] inside a [ProviderScope] and a [MaterialApp].
  ///
  /// Retries are off: Riverpod retries failing providers by default, which
  /// would hold a widget in its loading state instead of surfacing the error.
  Future<void> pumpScoped(Widget child, {List<Override> overrides = const []}) {
    return pumpWidget(
      ProviderScope(
        retry: (retryCount, error) => null,
        overrides: overrides,
        child: MaterialApp(home: child),
      ),
    );
  }
}
