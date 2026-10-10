import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pet_health_tracker/core/app.dart';
import 'package:pet_health_tracker/core/firebase_providers.dart';
import 'package:pet_health_tracker/data/household_repository.dart';
import 'package:pet_health_tracker/data/pet_repository.dart';
import 'package:pet_health_tracker/features/household/create_household_screen.dart';
import 'package:pet_health_tracker/features/household/home_screen.dart';
import 'package:pet_health_tracker/features/household/member_name_screen.dart';

import '../helpers.dart';

class MockHouseholdRepository extends Mock implements HouseholdRepository {}

void main() {
  final user = fakeUser(uid: 'u1');

  testWidgets('shows a spinner while the household loads', (tester) async {
    final repository = MockHouseholdRepository();
    when(() => repository.watchMyHousehold('u1')).thenAnswer((_) => const Stream.empty());

    await tester.pumpScoped(
      HouseholdGate(user: user),
      overrides: [householdRepositoryProvider.overrideWithValue(repository)],
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('shows create-household when the user has none', (tester) async {
    await tester.pumpScoped(
      HouseholdGate(user: user),
      overrides: [
        householdRepositoryProvider.overrideWithValue(HouseholdRepository(FakeFirebaseFirestore())),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.byType(CreateHouseholdScreen), findsOneWidget);
  });

  testWidgets('shows home when the user has a household', (tester) async {
    final repository = HouseholdRepository(FakeFirebaseFirestore());
    await repository.createHousehold(name: 'The Den', ownerUid: 'u1', ownerName: 'Tom');

    await tester.pumpScoped(
      HouseholdGate(user: user),
      overrides: [
        householdRepositoryProvider.overrideWithValue(repository),
        petRepositoryProvider.overrideWithValue(PetRepository(FakeFirebaseFirestore())),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('The Den'), findsWidgets);
  });

  testWidgets('asks a member with no name for one, then shows home', (tester) async {
    final firestore = FakeFirebaseFirestore();
    await firestore.doc('households/h1').set({
      'name': 'The Den',
      'memberIds': ['u1'],
      'adminIds': ['u1'],
    });

    await tester.pumpScoped(
      HouseholdGate(user: user),
      overrides: [
        householdRepositoryProvider.overrideWithValue(HouseholdRepository(firestore)),
        petRepositoryProvider.overrideWithValue(PetRepository(FakeFirebaseFirestore())),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.byType(MemberNameScreen), findsOneWidget);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
    expect((await firestore.doc('households/h1/members/u1').get()).data()!['name'], 'Tom');
  });

  testWidgets('shows the error and retries on tap', (tester) async {
    final repository = MockHouseholdRepository();
    when(() => repository.watchMyHousehold('u1')).thenAnswer((_) => Stream.error('offline'));

    await tester.pumpScoped(
      HouseholdGate(user: user),
      overrides: [householdRepositoryProvider.overrideWithValue(repository)],
    );
    await tester.pumpAndSettle();

    expect(find.text('offline'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Retry'));
    await tester.pumpAndSettle();

    verify(() => repository.watchMyHousehold('u1')).called(2);
  });
}
