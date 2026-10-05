import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pet_health_tracker/core/firebase_providers.dart';
import 'package:pet_health_tracker/data/household.dart';
import 'package:pet_health_tracker/data/pet.dart';
import 'package:pet_health_tracker/data/pet_repository.dart';
import 'package:pet_health_tracker/features/pets/pet_form_screen.dart';
import 'package:pet_health_tracker/features/settings/settings_screen.dart';

import '../../helpers.dart';

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
      ],
    );
  }

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
}
