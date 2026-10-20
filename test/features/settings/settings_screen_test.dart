import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
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
import 'package:pet_health_tracker/features/settings/transfer_ownership_screen.dart';

import '../../helpers.dart';

class MockHouseholdRepository extends Mock implements HouseholdRepository {}

void main() {
  const household = Household(
    id: 'h1',
    name: 'The Den',
    memberIds: ['admin', 'member'],
    adminIds: ['admin'],
    ownerId: 'admin',
  );

  late PetRepository pets;
  late FakeFirebaseFirestore firestore;
  late MockAuthRepository auth;

  setUp(() async {
    pets = PetRepository(FakeFirebaseFirestore());
    firestore = FakeFirebaseFirestore();
    await firestore.doc('households/h1').set({
      'name': household.name,
      'memberIds': household.memberIds,
      'adminIds': household.adminIds,
      'ownerId': household.ownerId,
    });
    auth = MockAuthRepository();
    when(auth.signOut).thenAnswer((_) async {});
  });

  Future<void> pumpSettings(WidgetTester tester, {String uid = 'admin'}) {
    return tester.pumpScoped(
      SettingsScreen(household: household, uid: uid),
      overrides: [
        petRepositoryProvider.overrideWithValue(pets),
        householdRepositoryProvider.overrideWithValue(HouseholdRepository(firestore)),
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

  testWidgets('the owner can open transfer ownership', (tester) async {
    await pumpSettings(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Transfer ownership'));
    await tester.pumpAndSettle();

    expect(find.byType(TransferOwnershipScreen), findsOneWidget);
  });

  testWidgets('only the owner can transfer ownership', (tester) async {
    await firestore.doc('households/h1').update({
      'adminIds': ['admin', 'member'],
    });

    await pumpSettings(tester, uid: 'member');
    await tester.pumpAndSettle();

    expect(find.text('Transfer ownership'), findsNothing);
  });

  testWidgets('with no one else in the household, transfer is off and says why', (tester) async {
    await firestore.doc('households/h1').update({
      'memberIds': ['admin'],
    });

    await pumpSettings(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Transfer ownership'));
    await tester.pumpAndSettle();

    expect(find.text('Invite someone first'), findsOneWidget);
    expect(find.byType(TransferOwnershipScreen), findsNothing);
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

  group('renaming', () {
    Future<void> openRename(WidgetTester tester) async {
      await pumpSettings(tester);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Household name'));
      await tester.pumpAndSettle();
    }

    testWidgets('admins see the household name', (tester) async {
      await pumpSettings(tester);
      await tester.pumpAndSettle();

      expect(find.widgetWithText(ListTile, 'Household name'), findsOneWidget);
      expect(find.text('The Den'), findsOneWidget);
    });

    testWidgets('members who are not admins cannot rename', (tester) async {
      await pumpSettings(tester, uid: 'member');
      await tester.pumpAndSettle();

      expect(find.text('Household name'), findsNothing);
    });

    testWidgets('an admin renames the household', (tester) async {
      await openRename(tester);

      expect(find.widgetWithText(TextField, 'The Den'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '  The Burrow  ');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect((await firestore.doc('households/h1').get()).data()!['name'], 'The Burrow');
      expect(find.text('The Burrow'), findsOneWidget);
    });

    testWidgets('an empty name is not saved', (tester) async {
      await openRename(tester);

      await tester.enterText(find.byType(TextField), '   ');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Enter a name'), findsOneWidget);
      expect((await firestore.doc('households/h1').get()).data()!['name'], 'The Den');
    });

    testWidgets('cancelling keeps the name', (tester) async {
      await openRename(tester);

      await tester.enterText(find.byType(TextField), 'The Burrow');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect((await firestore.doc('households/h1').get()).data()!['name'], 'The Den');
    });

    testWidgets('leaving after a rename asks with the new name', (tester) async {
      await firestore.doc('households/h1').update({'name': 'The Burrow'});
      await pumpSettings(tester, uid: 'member');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Leave household'));
      await tester.pumpAndSettle();

      expect(find.text('Leave The Burrow?'), findsOneWidget);
    });
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
    Future<void> openSettings(
      WidgetTester tester, {
      required String uid,
      Household? inHousehold,
    }) async {
      await tester.pumpScoped(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (context) => SettingsScreen(household: inHousehold ?? household, uid: uid),
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
      expect(find.textContaining('show "Former member"'), findsOneWidget);

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

    testWidgets("an admin who isn't the owner can leave", (tester) async {
      const twoAdmins = Household(
        id: 'h1',
        name: 'The Den',
        memberIds: ['admin', 'member'],
        adminIds: ['admin', 'member'],
        ownerId: 'admin',
      );
      await openSettings(tester, uid: 'member', inHousehold: twoAdmins);

      await tester.tap(find.text('Leave household'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Leave'));
      await tester.pumpAndSettle();

      verify(() => households.leaveHousehold(householdId: 'h1', uid: 'member')).called(1);
    });

    testWidgets("the owner can't leave, and is told why", (tester) async {
      await openSettings(tester, uid: 'admin');

      expect(find.text("The owner can't leave a household"), findsOneWidget);
      await tester.tap(find.text('Leave household'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
    });
  });

  group('deleting', () {
    late MockHouseholdRepository households;

    setUp(() {
      households = MockHouseholdRepository();
      when(() => households.deleteHousehold(any())).thenAnswer((_) async {});
    });

    /// Opens settings on top of a placeholder root, as the app does.
    Future<void> openSettings(
      WidgetTester tester, {
      String uid = 'admin',
      Household? inHousehold,
    }) async {
      await tester.pumpScoped(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (context) => SettingsScreen(household: inHousehold ?? household, uid: uid),
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

    Future<void> confirmDelete(WidgetTester tester) async {
      await tester.tap(find.text('Delete household'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
    }

    testWidgets('only the owner can delete the household', (tester) async {
      const twoAdmins = Household(
        id: 'h1',
        name: 'The Den',
        memberIds: ['admin', 'member'],
        adminIds: ['admin', 'member'],
        ownerId: 'admin',
      );
      await openSettings(tester, uid: 'member', inHousehold: twoAdmins);
      expect(find.text('Delete household'), findsNothing);
    });

    testWidgets('the owner deletes after confirming, and returns to the root', (tester) async {
      await openSettings(tester);

      await tester.tap(find.text('Delete household'));
      await tester.pumpAndSettle();
      expect(find.text('Delete The Den?'), findsOneWidget);
      expect(find.textContaining("can't be undone"), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await tester.pumpAndSettle();

      verify(() => households.deleteHousehold('h1')).called(1);
      expect(find.byType(SettingsScreen), findsNothing);
    });

    testWidgets('cancelling keeps the household', (tester) async {
      await openSettings(tester);

      await tester.tap(find.text('Delete household'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      verifyNever(() => households.deleteHousehold(any()));
      expect(find.byType(SettingsScreen), findsOneWidget);
    });

    testWidgets('waits for the server, showing progress', (tester) async {
      final deleted = Completer<void>();
      when(() => households.deleteHousehold(any())).thenAnswer((_) => deleted.future);
      await openSettings(tester);

      await confirmDelete(tester);
      await tester.pump();

      expect(find.text('Deleting The Den…'), findsOneWidget);
      expect(find.byType(SettingsScreen), findsOneWidget);

      deleted.complete();
      await tester.pumpAndSettle();
      expect(find.byType(SettingsScreen), findsNothing);
    });

    testWidgets('a failed delete stays in settings and says to check the connection', (
      tester,
    ) async {
      when(() => households.deleteHousehold(any())).thenAnswer(
        (_) async => throw FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
      );
      await openSettings(tester);

      await confirmDelete(tester);
      await tester.pumpAndSettle();

      expect(find.text('Deleting The Den…'), findsNothing);
      expect(find.byType(SettingsScreen), findsOneWidget);
      expect(
        find.text("Couldn't delete The Den. Check your connection and try again."),
        findsOneWidget,
      );
    });
  });
}
