import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_health_tracker/core/firebase_providers.dart';
import 'package:pet_health_tracker/data/household.dart';
import 'package:pet_health_tracker/data/household_repository.dart';
import 'package:pet_health_tracker/data/pet.dart';
import 'package:pet_health_tracker/data/pet_repository.dart';
import 'package:pet_health_tracker/data/symptom_log_repository.dart';
import 'package:pet_health_tracker/features/pets/archived_pets_screen.dart';
import 'package:pet_health_tracker/features/symptoms/pet_logs_screen.dart';

import '../../helpers.dart';

/// Fails to load the archived pets the first time, then loads them.
class _FlakyPetRepository extends PetRepository {
  _FlakyPetRepository(super.firestore);

  var _failed = false;

  @override
  Stream<List<Pet>> watchArchivedPets(String householdId) {
    if (_failed) return super.watchArchivedPets(householdId);
    _failed = true;
    return Stream.error('offline');
  }
}

void main() {
  const household = Household(
    id: 'h1',
    name: 'The Den',
    memberIds: ['admin', 'member'],
    adminIds: ['admin'],
    ownerId: 'admin',
  );

  late FakeFirebaseFirestore firestore;
  late PetRepository pets;
  late String oldTimer;

  setUp(() async {
    firestore = FakeFirebaseFirestore();
    await firestore.doc('households/h1').set({
      'name': household.name,
      'memberIds': household.memberIds,
      'adminIds': household.adminIds,
      'ownerId': household.ownerId,
    });
    pets = PetRepository(firestore);
    await pets.addPet(householdId: 'h1', name: 'Boogie', species: Species.dog);
    await pets.addPet(householdId: 'h1', name: 'Old Timer', species: Species.cat, breed: 'Tabby');
    oldTimer = (await pets.watchPets('h1').first).firstWhere((p) => p.name == 'Old Timer').id;
    await pets.archivePet(householdId: 'h1', petId: oldTimer);
  });

  Future<void> pumpArchived(
    WidgetTester tester, {
    required String uid,
    PetRepository? repository,
  }) async {
    await tester.pumpScoped(
      ArchivedPetsScreen(household: household, uid: uid),
      overrides: [
        petRepositoryProvider.overrideWithValue(repository ?? pets),
        householdRepositoryProvider.overrideWithValue(HouseholdRepository(firestore)),
        symptomLogRepositoryProvider.overrideWithValue(SymptomLogRepository(firestore)),
      ],
    );
    await tester.pumpAndSettle();
  }

  testWidgets('lists only the archived pets', (tester) async {
    await pumpArchived(tester, uid: 'member');

    expect(find.text('Archived pets'), findsOneWidget);
    expect(find.text('Old Timer'), findsOneWidget);
    expect(find.text('Cat · Tabby'), findsOneWidget);
    expect(find.text('Boogie'), findsNothing);
  });

  testWidgets("tapping a pet opens its history, knowing the user's role", (tester) async {
    await pumpArchived(tester, uid: 'member');
    await tester.tap(find.text('Old Timer'));
    await tester.pumpAndSettle();

    final screen = tester.widget<PetLogsScreen>(find.byType(PetLogsScreen));
    expect(
      (screen.householdId, screen.pet.id, screen.uid, screen.isAdmin),
      ('h1', oldTimer, 'member', false),
    );
  });

  testWidgets('an admin unarchives a pet, bringing it back', (tester) async {
    await pumpArchived(tester, uid: 'admin');
    await tester.tap(find.widgetWithText(TextButton, 'Unarchive'));
    await tester.pumpAndSettle();

    expect(find.text('No archived pets'), findsOneWidget);
    expect((await pets.watchPets('h1').first).map((p) => p.name), ['Boogie', 'Old Timer']);
  });

  testWidgets('an admin removed while the screen is open loses Unarchive', (tester) async {
    await pumpArchived(tester, uid: 'admin');
    expect(find.text('Unarchive'), findsOneWidget);

    await firestore.doc('households/h1').update({
      'memberIds': ['member'],
      'adminIds': ['member'],
    });
    await tester.pumpAndSettle();

    expect(find.text('Old Timer'), findsOneWidget);
    expect(find.text('Unarchive'), findsNothing);
  });

  testWidgets("members who aren't admins can't unarchive", (tester) async {
    await pumpArchived(tester, uid: 'member');

    expect(find.text('Unarchive'), findsNothing);
  });

  testWidgets('shows the error when archived pets fail to load, and retries on tap', (
    tester,
  ) async {
    await pumpArchived(tester, uid: 'member', repository: _FlakyPetRepository(firestore));
    expect(find.text('offline'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.text('Old Timer'), findsOneWidget);
  });
}
