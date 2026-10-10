import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pet_health_tracker/core/app_version.dart';
import 'package:pet_health_tracker/core/firebase_providers.dart';
import 'package:pet_health_tracker/data/household.dart';
import 'package:pet_health_tracker/data/household_repository.dart';
import 'package:pet_health_tracker/data/invite_repository.dart';
import 'package:pet_health_tracker/data/pet.dart';
import 'package:pet_health_tracker/data/pet_repository.dart';
import 'package:pet_health_tracker/features/household/invite_providers.dart';
import 'package:pet_health_tracker/features/household/invite_screen.dart';
import 'package:pet_health_tracker/features/pets/pet_form_screen.dart';
import 'package:pet_health_tracker/features/settings/settings_screen.dart';

import '../../helpers.dart';

class MockHouseholdRepository extends Mock implements HouseholdRepository {}

void main() {
  const household = Household(
    id: 'h1',
    name: 'The Den',
    memberIds: ['admin', 'member'],
    adminIds: ['admin'],
  );

  late PetRepository pets;
  late MockAuthRepository auth;

  setUp(() {
    pets = PetRepository(FakeFirebaseFirestore());
    auth = MockAuthRepository();
    when(auth.signOut).thenAnswer((_) async {});
  });

  Future<void> pumpSettings(WidgetTester tester, {String uid = 'admin'}) {
    return tester.pumpScoped(
      SettingsScreen(household: household, uid: uid),
      overrides: [
        petRepositoryProvider.overrideWithValue(pets),
        authRepositoryProvider.overrideWithValue(auth),
        appVersionProvider.overrideWith((ref) async => '0.0.1 (31)'),
        inviteRepositoryProvider.overrideWithValue(InviteRepository(FakeFirebaseFirestore())),
        inviteCodeStoreProvider.overrideWithValue(FakeInviteCodeStore()),
      ],
    );
  }

  testWidgets('shows the app version and build number', (tester) async {
    await pumpSettings(tester, uid: 'member');
    await tester.pumpAndSettle();

    expect(find.text('Version'), findsOneWidget);
    expect(find.text('0.0.1 (31)'), findsOneWidget);
  });

  testWidgets("lists the household's pets", (tester) async {
    await pets.addPet(householdId: 'h1', name: 'Boogie', species: Species.dog, breed: 'Beagle');

    await pumpSettings(tester);
    await tester.pumpAndSettle();

    expect(find.text('Boogie'), findsOneWidget);
    expect(find.text('Dog · Beagle'), findsOneWidget);
  });

  testWidgets('admins can open the add-pet screen', (tester) async {
    await pumpSettings(tester);
    await tester.tap(find.text('Add pet'));
    await tester.pumpAndSettle();

    expect(find.byType(PetFormScreen), findsOneWidget);
    expect(find.text('Add a pet'), findsOneWidget);
  });

  testWidgets('admins can open the invite screen', (tester) async {
    await pumpSettings(tester);
    await tester.tap(find.text('Invite someone'));
    await tester.pumpAndSettle();

    expect(find.byType(InviteScreen), findsOneWidget);
  });

  testWidgets('members who are not admins cannot invite', (tester) async {
    await pumpSettings(tester, uid: 'member');
    await tester.pumpAndSettle();

    expect(find.text('Invite someone'), findsNothing);
  });

  testWidgets('members who are not admins cannot add pets', (tester) async {
    await pumpSettings(tester, uid: 'member');
    await tester.pumpAndSettle();

    expect(find.text('Add pet'), findsNothing);
  });

  testWidgets('admins can open a pet to edit it', (tester) async {
    await pets.addPet(householdId: 'h1', name: 'Boogie', species: Species.dog);

    await pumpSettings(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Boogie'));
    await tester.pumpAndSettle();

    expect(find.byType(PetFormScreen), findsOneWidget);
    expect(find.text('Edit Boogie'), findsOneWidget);
  });

  testWidgets('members who are not admins cannot edit pets', (tester) async {
    await pets.addPet(householdId: 'h1', name: 'Boogie', species: Species.dog);

    await pumpSettings(tester, uid: 'member');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Boogie'));
    await tester.pumpAndSettle();

    expect(find.byType(PetFormScreen), findsNothing);
  });

  testWidgets('signs out and returns to the root route', (tester) async {
    await tester.pumpScoped(
      Builder(
        builder: (context) => TextButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (context) => const SettingsScreen(household: household, uid: 'admin'),
            ),
          ),
          child: const Text('open'),
        ),
      ),
      overrides: [
        petRepositoryProvider.overrideWithValue(pets),
        authRepositoryProvider.overrideWithValue(auth),
      ],
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();

    verify(auth.signOut).called(1);
    expect(find.byType(SettingsScreen), findsNothing);
  });

  group('leaving', () {
    late MockHouseholdRepository households;

    setUp(() {
      households = MockHouseholdRepository();
      when(
        () => households.leaveHousehold(
          householdId: any(named: 'householdId'),
          uid: any(named: 'uid'),
        ),
      ).thenAnswer((_) async {});
    });

    /// Opens settings on top of a placeholder root, as the app does.
    Future<void> openSettings(WidgetTester tester, {required String uid}) async {
      await tester.pumpScoped(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (context) => SettingsScreen(household: household, uid: uid),
              ),
            ),
            child: const Text('open'),
          ),
        ),
        overrides: [
          petRepositoryProvider.overrideWithValue(pets),
          householdRepositoryProvider.overrideWithValue(households),
        ],
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('a member leaves after confirming, and returns to the root', (tester) async {
      await openSettings(tester, uid: 'member');

      await tester.tap(find.text('Leave household'));
      await tester.pumpAndSettle();
      expect(find.text('Leave The Den?'), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'Leave'));
      await tester.pumpAndSettle();

      verify(() => households.leaveHousehold(householdId: 'h1', uid: 'member')).called(1);
      expect(find.byType(SettingsScreen), findsNothing);
    });

    testWidgets('cancelling keeps the member in the household', (tester) async {
      await openSettings(tester, uid: 'member');

      await tester.tap(find.text('Leave household'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      verifyNever(
        () => households.leaveHousehold(
          householdId: any(named: 'householdId'),
          uid: any(named: 'uid'),
        ),
      );
      expect(find.byType(SettingsScreen), findsOneWidget);
    });

    testWidgets("admins can't leave, and are told why", (tester) async {
      await openSettings(tester, uid: 'admin');

      expect(find.text("Admins can't leave a household"), findsOneWidget);
      await tester.tap(find.text('Leave household'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
    });
  });
}
